# frozen_string_literal: true

module CouchbaseOrm
  module QueryHelper
    extend ActiveSupport::Concern

    module ClassMethods
      def build_match(key, value)
        key = 'meta().id' if key.to_s == 'id'
        if value.nil?
          "#{key} IS NOT VALUED"
        elsif value.is_a?(Hash)
          build_match_hash(key, value)
        elsif value.is_a?(Array) && value.include?(nil)
          "(#{build_match(key, nil)} OR #{build_match(key, value.compact)})"
        elsif value.is_a?(Array)
          "#{key} IN #{quote(value)}"
        else
          "#{key} = #{quote(value)}"
        end
      end

      def build_match_hash(key, value)
        value.map do |k, v|
          case k
          when :_gt
            "#{key} > #{quote(v)}"
          when :_gte
            "#{key} >= #{quote(v)}"
          when :_lt
            "#{key} < #{quote(v)}"
          when :_lte
            "#{key} <= #{quote(v)}"
          when :_ne
            "#{key} != #{quote(v)}"

          # TODO: v2
          # when :_in
          #     "#{key} IN #{quote(v)}"
          # when :_nin
          #     "#{key} NOT IN #{quote(v)}"
          # when :_like
          #     "#{key} LIKE #{quote(v)}"
          # when :_nlike
          #     "#{key} NOT LIKE #{quote(v)}"
          # when :_between
          #     "#{key} BETWEEN #{quote(v[0])} AND #{quote(v[1])}"
          # when :_nbetween
          #     "#{key} NOT BETWEEN #{quote(v[0])} AND #{quote(v[1])}"
          # when :_exists
          #     "#{key} IS #{v ? "" : "NOT "}VALUED"
          # when :_regex
          #     "#{key} REGEXP #{quote(v)}"
          # when :_nregex
          #     "#{key} NOT REGEXP #{quote(v)}"
          # when :_match
          #     "#{key} MATCH #{quote(v)}"
          # when :_nmatch
          #     "#{key} NOT MATCH #{quote(v)}"

          # TODO: v3
          # when :_any
          #     "#{key} ANY #{quote(v)}"
          # when :_nany
          #     "#{key} NOT ANY #{quote(v)}"
          # when :_all
          #     "#{key} ALL #{quote(v)}"
          # when :_nall
          #     "#{key} NOT ALL #{quote(v)}"
          # when :_within
          #     "#{key} WITHIN #{quote(v)}"
          # when :_nwithin
          #    "#{key} NOT WITHIN #{quote(v)}"
          else
            if attribute_types[key.to_s].is_a?(CouchbaseOrm::Types::Array)
              "any #{key.to_s.singularize} in #{key} satisfies #{build_match("#{key.to_s.singularize}.#{k}", v)} end"
            else
              build_match("#{key}.#{k}", v)
            end
          end
        end.join(' AND ')
      end

      def build_not_match(key, value)
        key = 'meta().id' if key.to_s == 'id'
        if value.nil?
          "#{key} IS VALUED"
        elsif value.is_a?(Array) && value.include?(nil)
          "(#{build_not_match(key, nil)} AND #{build_not_match(key, value.compact)})"
        elsif value.is_a?(Array)
          "#{key} NOT IN #{quote(value)}"
        else
          "#{key} != #{quote(value)}"
        end
      end

      def serialize_value(key, value_before_type_cast)
        value =
          if value_before_type_cast.is_a?(Array)
            value_before_type_cast.map do |v|
              attribute_types[key.to_s].serialize(attribute_types[key.to_s].cast(v))
            end
          else
            attribute_types[key.to_s].serialize(attribute_types[key.to_s].cast(value_before_type_cast))
          end
        CouchbaseOrm.logger.debug {
          "convert_values: #{key} => #{value_before_type_cast.inspect} => #{value.inspect} #{value.class} #{attribute_types[key.to_s]}"
        }
        value
      end

      def quote(value)
        if value.is_a? String
          "'#{N1ql.sanitize(value)}'"
        elsif value.is_a? Array
          "[#{value.map{ |v| quote(v) }.join(', ')}]"
        elsif value.nil?
          nil
        else
          N1ql.sanitize(value).to_s
        end
      end
    end
  end
end
