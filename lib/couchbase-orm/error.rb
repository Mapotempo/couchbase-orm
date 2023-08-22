# frozen_string_literal: true, encoding: ASCII-8BIT

module CouchbaseOrm
    class Error < ::StandardError
        attr_reader :record
        
        def initialize(message = nil, record = nil)
            @record = record
            super(message)
        end

        class RecordInvalid < Error
            def initialize(record = nil)
                if record
                    @record = record
                    errors = @record.errors.full_messages.join(", ")
                    message = I18n.t(:"#{@record.class.i18n_scope}.errors.messages.record_invalid", errors: errors, default: :"errors.messages.record_invalid")
                else
                    message = "Record invalid"
                end
                super(message, record)
            end
        end
        class TypeMismatchError < Error; end
        class RecordExists < Error; end
        class EmptyNotAllowed < Error; end
        class DocumentNotFound < Error; end
        class RecordNotSaved < Error; end
    end
end
