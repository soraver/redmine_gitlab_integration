module GitlabInt
  module ProjectPatch
    def self.included(base)
      base.send(:include, InstanceMethods) 
      base.class_eval do
        alias_method_chain :delete_unsafe_attributes, :gitlab
        has_many :git_lab_repositories, dependent: :destroy
        validate :gitlab_errors?
        attr_accessor :gitlab_err
      end
    end
  
    module InstanceMethods
      def delete_unsafe_attributes_with_gitlab(attrs, user)
        if attrs["gitlab_token"] && !attrs["gitlab_token"].empty? && (attrs["gitlab_create"] == "true")
          create_gitlab_repository(attrs)
        end
        delete_unsafe_attributes_without_gitlab(attrs, user)
      end

      def create_gitlab_repository(attrs)
        begin
          glr = GitLabRepository.new
          glr.set_attributes({ title: attrs['gitlab_name'], description: attrs['gitlab_description'],
                               visibility: attrs['visibility'], token: attrs['gitlab_token'],
                               context: :create_with_project })
          glr.save
          self.git_lab_repositories << glr
        rescue
          @gitlab_err = true
        end
      end

      def gitlab_errors?
          errors.add(:base, t(:gitlab_creation_error)) if @gitlab_err
      end
    end
  end
end
