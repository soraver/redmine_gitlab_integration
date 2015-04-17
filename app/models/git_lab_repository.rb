require 'net/http'
class GitLabRepository < ActiveRecord::Base
  unloadable
  belongs_to :project
  validate :gitlab_repo_created?
  before_destroy :destroy_repository
  attr_protected :url, :project
  acts_as_event datetime: :created_at,
                title: ->(r) { "Gitlab Plugin - #{r.title}" },
                url: ->(r) { { controller: "git_lab_repositories", action: "index", project_id: r.project.id } }
  acts_as_activity_provider permission: nil,
                            timestamp: :created_at,
                            find_options: { include: :project },
                            author_key: nil

  include GitlabInt::GitlabMethods

  def set_attributes(attrs)
    begin
      case attrs[:context]
      when :add_by_url
        # Just add repository by url
        self.url = format_url attrs[:repository_url]
        self.title = attrs[:title]
      when :create_with_project
        create_gitlab_repository(attrs)
      when :create_and_add_to_project
        # Create repository with members in gitlab and add it in redmine
        create_gitlab_repository(attrs)
      else
        raise
      end
    rescue
      @gitlab_err = true
    end
  end

  def author
    User.current
  end
  
  def destroy_repository
    gitlab_destroy({ token: User.current.gitlab_token, id: self.gitlab_id }) if self.gitlab_id && Setting.plugin_redmine_gitlab_integration['gitlab_autoremove'] == "enabled"
  end

  private

  def create_gitlab_repository(attrs)
    create_gitlab_group(attrs) unless attrs[:group] # project new or has no repositories
    glp = gitlab_create(attrs) # create repository in gitlab
    self.description = attrs[:description]
    self.title = attrs[:title]
    self.url = get_url_of glp
    self.gitlab_id = get_id_of glp # repository id in gitlab
    attrs[:group]
  end

  def create_gitlab_group(attrs)
    attrs[:group] = gitlab_create_group(attrs)
    attrs[:op] = :add
    gitlab_member_and_group(attrs) # add project owner to group
    set_gitlab_group(attrs) if attrs[:context] == :create_and_add_to_project
  end

  def set_gitlab_group(attrs)
    project = Project.find(attrs[:project_id])
    project.gitlab_group = attrs[:group]
    project.save
    members = project.members.map { |m| { token: m.user.gitlab_token, role: m.roles.first.id } }
    gitlab_add_members(group: attrs[:group], members: members)
  end

  def format_url(url)
    url.gsub('git@', 'http://')
  end

  def gitlab_repo_created?
    self.errors[:base] << "Error" if @gitlab_err
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
