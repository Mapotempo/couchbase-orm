# frozen_string_literal: true

module MTLibcouchbase
  class QueryN1QL
    N1P_QUERY_STATEMENT = 1
    N1P_CONSISTENCY_REQUEST = 2

    def initialize(connection, reactor, n1ql, **_opts)
      @connection = connection
      @reactor = reactor

      @n1ql = n1ql
      @request_handle = FFI::MemoryPointer.new :pointer, 1
    end

    attr_reader :connection, :n1ql

    def get_count(metadata)
      metadata[:metrics][:resultCount]
    end

    def perform(limit: nil, **_options, &blk)
      raise 'not connected' unless @connection.handle
      raise 'query already in progress' if @query_text
      raise 'callback required' unless blk

      # customise the size based on the request being made
      orig_limit = @n1ql.limit
      begin
        @n1ql.limit = limit if orig_limit && limit && (orig_limit > limit)
        @query_text = @n1ql.to_s
      rescue StandardError
        @query_text = nil
        raise
      ensure
        @n1ql.limit = orig_limit
      end

      @reactor.schedule do
        @error = nil
        @callback = blk

        @cmd = Ext::CMDN1QL.new
        @params = Ext.n1p_new
        err = Ext.n1p_setconsistency(@params, N1P_CONSISTENCY_REQUEST)
        if err == :success
          err = Ext.n1p_setquery(@params, @query_text, @query_text.bytesize, N1P_QUERY_STATEMENT)
          if err == :success

            err = Ext.n1p_mkcmd(@params, @cmd)
            if err == :success
              pointer = @cmd.to_ptr
              @connection.requests[pointer.address] = self

              @cmd[:callback] = @connection.get_callback(:n1ql_callback)
              @cmd[:handle] = @request_handle

              err = Ext.n1ql_query(@connection.handle, pointer, @cmd)
              error(Error.lookup(err).new('full text search not scheduled')) if err != :success
            else
              error(Error.lookup(err).new('failed to build full text search command'))
            end
          else
            error(Error.lookup(err).new('failed to build full text search query structure'))
          end
        else
          error(Error.lookup(err).new('failed set consistency value'))
        end
      end
    end

    # Row is JSON value representing the result
    def received(row)
      return if @error

      @callback.call(false, row)
    rescue StandardError => e
      @error = e
      cancel
    end

    # Example metadata
    # {:requestID=>"36162fce-ef39-4821-bf03-449e4073185d", :signature=>{:*=>"*"}, :results=>[], :status=>"success",
    #  :metrics=>{:elapsedTime=>"15.298243ms", :executionTime=>"15.256975ms", :resultCount=>12, :resultSize=>8964}}
    def received_final(metadata)
      @query_text = nil

      @connection.requests.delete(@cmd.to_ptr.address)
      @cmd = nil

      Ext.n1p_free(@params)
      @params = nil

      if @error
        if @error == :cancelled
          @callback.call(:final, metadata)
        else
          @callback.call(:error, @error)
        end
      else
        @callback.call(:final, metadata)
      end
    end

    def error(obj)
      @error = obj
      received_final(nil)
    end

    def cancel
      @error ||= :cancelled
      @reactor.schedule do
        if @connection.handle && @cmd
          Ext.n1ql_cancel(@connection.handle, @handle_ptr.get_pointer(0))
          received_final(nil)
        end
      end
    end
  end
end
