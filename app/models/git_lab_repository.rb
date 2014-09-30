class GitLabRepository < ActiveRecord::Base
  unloadable
  belongs_to :project
  validate :gitlab_repo_created?
  include GitlabInt::GitlabMethods

  def smart_attributes=(attrs)
    begin
      case attrs[:context]
      when :add_by_url
        # Just add repository by url
        self.url = attrs[:repository_url] 
      when :create_with_project
        glp = gitlab_create(attrs) # create repository in gitlab
        self.url = get_url_of glp
        self.gitlab_id = get_id_of glp # repository id in gitlab
      when :create_and_add_to_project
          # Create repository in gitlab and add it in redmine
          attrs[:token] = User.current.gitlab_token
          glp = gitlab_create(attrs) # create repository in gitlab
          self.url = get_url_of glp
          self.gitlab_id = get_id_of glp # repository id in gitlab
          attrs[:token] = User.current.gitlab_token # add token in attributes hash
          members = Project.find(attrs[:project_id]).members.map { |m| { login: m.user.login, role: m.roles.first.id } }
          gitlab_add_members(members: members, repository: self.gitlab_id, token: attrs[:token])
      end 
    rescue
      @gitlab_err = true
    end
  end

  private

  def gitlab_repo_created?
    errors.add(:base, I18n.t(:gitlab_creation_error)) if @gitlab_err
  end

  def get_url_of(obj)
  	replace_localhost(obj.to_h['http_url_to_repo'])
  end

  def get_id_of(obj)
    obj.to_h['id']
  end
  
  def replace_localhost(str)
  	str.gsub('http://localhost', Setting.plugin_redmine_gitlab_integration['gitlab_url']) # if redmine and gitlab are hosted on same server
  end
end
