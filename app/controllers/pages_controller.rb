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
end