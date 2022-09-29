# frozen_string_literal: true

module CouchbaseOrm
  module Join
    private

    # join adds methods for retrieving the join model by user or group, and
    # methods for retrieving either model through the join model (e.g all
    # users who are in a group). model_a and model_b must be strings or symbols
    # and are assumed to be singularised, underscored versions of model names
    def join(model_a, model_b, options = {})
      # store the join model names for use by has_many associations
      @join_models = [model_a.to_s, model_b.to_s]

      # join :user, :group => design_document :ugj
      doc_name = options[:design_document] || "#{model_a.to_s[0]}#{model_b.to_s[0]}j".to_sym
      design_document doc_name

      # a => b
      add_single_sided_features(model_a)
      add_joint_lookups(model_a, model_b)

      # b => a
      add_single_sided_features(model_b)
      add_joint_lookups(model_b, model_a, true)

      # use Index to allow lookups of joint records more efficiently than
      # with a view or search
      index ["#{model_a}_id".to_sym, "#{model_b}_id".to_sym], :join
    end

    def add_single_sided_features(model)
      # belongs_to :group
      belongs_to model

      # view :by_group_id
      view "by_#{model}_id"

      # find_by_group_id
      instance_eval "
                def self.find_by_#{model}_id(#{model}_id) # def self.find_by_group_id(group_id)
                    by_#{model}_id(key: #{model}_id)      #   by_group_id(key: group_id)
                end                                       # end
            ", __FILE__, __LINE__ - 4
    end

    def add_joint_lookups(model_a, model_b, reverse = false)
      # find_by_user_id_and_group_id
      instance_eval "
                def self.find_by_#{model_a}_id_and_#{model_b}_id(#{model_a}_id, #{model_b}_id)                # def self.find_by_user_id_and_group_id(user_id, group_id)
                    self.find_by_join([#{reverse ? model_b : model_a}_id, #{reverse ? model_a : model_b}_id]) #   self.find_by_join([user_id, group_id])
                end                                                                                           # end
            ", __FILE__, __LINE__ - 4

      # user_ids_by_group_id
      instance_eval "
                def self.#{model_a}_ids_by_#{model_b}_id(#{model_b}_id)            # def self.user_ids_by_group_id(group_id)
                    self.find_by_#{model_b}_id(#{model_b}_id).map(&:#{model_a}_id) #   self.find_by_group_id(group_id).map(&:user_id)
                end                                                                # end
            ", __FILE__, __LINE__ - 4

      # users_by_group_id
      instance_eval "
                def self.#{model_a.to_s.pluralize}_by_#{model_b}_id(#{model_b}_id) # def self.users_by_group_id(group_id)
                    self.find_by_#{model_b}_id(#{model_b}_id).map(&:#{model_a})    #   self.find_by_group_id(group_id).map(&:user)
                end                                                                # end
            ", __FILE__, __LINE__ - 4
    end
  end
end
