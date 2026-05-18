class PagesController < ApplicationController
  def landing
    @featured_posts = Post.where(status: Post.statuses[:published], verified: true)
                          .includes(:user, :tags)
                          .order(created_at: :desc)
                          .limit(2)

    @team_members = User.where(role: User.roles[:author])
                        .left_joins(:posts)
                        .group("users.id")
                        .order(Arel.sql("COUNT(posts.id) DESC"))
                        .limit(3)
  end

  def team
    team_scope = User.joins(:posts)
                .where(posts: { status: Post.statuses[:published], verified: true })
                .select("users.*, COUNT(posts.id) AS published_posts_count")
                .group("users.id")
                .order(Arel.sql("COUNT(posts.id) DESC, users.created_at ASC"))

    members = team_scope.limit(7).to_a
    @featured_member = members.first
    @team_members = members.drop(1)

    @recent_posts_by_member = Post.where(user_id: members.map(&:id), status: Post.statuses[:published], verified: true)
                                  .includes(:tags)
                                  .order(created_at: :desc)
                                  .group_by(&:user_id)
  end
end