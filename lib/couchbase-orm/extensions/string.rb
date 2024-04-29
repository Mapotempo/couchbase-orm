module CouchbaseOrm
    module Extensions
        module String
            def reader
                delete("=").sub(/\_before\_type\_cast\z/, '')
            end
            
            def writer
                sub(/\_before\_type\_cast\z/, '') + "="
            end
            
            def writer?
                include?("=")
            end
            
            def before_type_cast?
                ends_with?("_before_type_cast")
            end
            
            def valid_method_name?
                /[@$"-]/ !~ self
            end
        end
    end
end

::String.__send__(:include, CouchbaseOrm::Extensions::String)
