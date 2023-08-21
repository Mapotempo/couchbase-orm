require "couchbase"
require 'couchbase-orm/error'

module CouchbaseOrm
    class CollectionProxy

        def get!(id, **options)
            @proxyfied.get(id, Couchbase::Options::Get.new(**options))
        rescue Couchbase::Error::DocumentNotFound => e
            raise CouchbaseOrm::Error::DocumentNotFound
        end

        def get(id, **options)
            @proxyfied.get(id, Couchbase::Options::Get.new(**options))
        rescue Couchbase::Error::DocumentNotFound
            nil
        end

        def get_multi!(*ids, **options)
            result = @proxyfied.get_multi(*ids, Couchbase::Options::GetMulti.new(**options))
            first_result_with_error = result.find(&:error)
            if first_result_with_error
                raise CouchbaseOrm::Error::DocumentNotFound 
            end
            result
        end

        def get_multi(*ids, **options)
            result = @proxyfied.get_multi(*ids, Couchbase::Options::GetMulti.new(**options))
            result.reject(&:error)
        end

        def replace(id, content, **options)
            @proxyfied.replace(id, content, Couchbase::Options::Replace.new(**options))
        rescue Couchbase::Error::DocumentNotFound
            raise CouchbaseOrm::Error::DocumentNotFound
        end

        def touch(id, expiry, **options)
            @proxyfied.replace(id, expiry,  Options::Touch.new(**options))
        rescue Couchbase::Error::DocumentNotFound
            raise CouchbaseOrm::Error::DocumentNotFound
        end

        def remove!(id, **options)
            @proxyfied.remove(id, Couchbase::Options::Remove.new(**options))
        rescue Couchbase::Error::DocumentNotFound
            raise CouchbaseOrm::Error::DocumentNotFound
        end

        def remove(id, **options)
            @proxyfied.remove(id, Couchbase::Options::Remove.new(**options))
        rescue Couchbase::Error::DocumentNotFound
            nil
        end

        def initialize(proxyfied)
            raise "Must proxy a non nil object" if proxyfied.nil?
            @proxyfied = proxyfied
        end
        
        if RUBY_VERSION.to_i >= 3
            def method_missing(name, *args, **options, &block)
                @proxyfied.public_send(name, *args, **options, &block)
            end
        else # :nocov:
            def method_missing(name, *args, &block) 
                @proxyfied.public_send(name, *args, &block)
            end
        end
    end
end
