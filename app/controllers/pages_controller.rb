class PagesController < ApplicationController
  def landing
    @featured_posts = Post.publicly_visible
                          .includes(:tags, :rich_text_body, :user, thumbnail_attachment: :blob)
                          .order(created_at: :desc)
                          .limit(2)

    @team_members = User.where(role: User.roles[:author], banned_at: nil)
                        .left_joins(:posts)
                        .group("users.id")
                        .order(Arel.sql("COUNT(posts.id) DESC"))
                        .limit(3)
                        .includes(avatar_attachment: :blob)
  end

  def team
    team_scope = User.where(banned_at: nil).joins(:posts)
                .where(posts: { status: Post.statuses[:published], verified: true })
                .select("users.*, COUNT(posts.id) AS published_posts_count")
                .group("users.id")
                .order(Arel.sql("COUNT(posts.id) DESC, users.created_at ASC"))

    members = team_scope.limit(7).includes(avatar_attachment: :blob).to_a
    @featured_member = members.first
    @team_members = members.drop(1)

    @recent_posts_by_member = Post.publicly_visible.where(user_id: members.map(&:id))
                                  .includes(:tags)
                                  .order(created_at: :desc)
                                  .group_by(&:user_id)
  end
end
