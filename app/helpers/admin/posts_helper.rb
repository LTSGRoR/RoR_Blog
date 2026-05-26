module Admin::PostsHelper
  def admin_post_stats(new_post_count:, awaiting_review_count:, pending_count:, draft_count:, reviewed_today_count:, verified_today_count:)
    [
      {
        label: t("admin.posts.index.stats.pending_posts"),
        value: new_post_count,
        container_class: "rounded-2xl border border-[#fecaca] bg-[#fff1f2] p-4 shadow-sm ring-1 ring-[#ffe4e6]",
        label_class: "text-[#9f1239]",
        value_class: "text-[#881337]"
      },
      {
        label: t("admin.posts.index.stats.awaiting_review"),
        value: awaiting_review_count,
        container_class: "rounded-2xl border border-rose-200 bg-rose-50 p-4 shadow-sm ring-1 ring-rose-100",
        label_class: "text-rose-700",
        value_class: "text-rose-800"
      },
      {
        label: t("admin.posts.index.stats.verified_today"),
        value: verified_today_count,
        container_class: "rounded-2xl border border-emerald-200 bg-emerald-50 p-4 shadow-sm ring-1 ring-emerald-100",
        label_class: "text-emerald-700",
        value_class: "text-emerald-800"
      },
      {
        label: t("admin.posts.index.stats.open"),
        value: draft_count,
        container_class: "rounded-2xl border border-slate-200 bg-white p-4 shadow-sm ring-1 ring-slate-100",
        label_class: "text-slate-600",
        value_class: "text-slate-900"
      },
      {
        label: t("admin.posts.index.stats.pending_revisions"),
        value: pending_count,
        container_class: "rounded-2xl border border-amber-200 bg-amber-50 p-4 shadow-sm ring-1 ring-amber-100",
        label_class: "text-amber-700",
        value_class: "text-amber-800"
      },
      {
        label: t("admin.posts.index.stats.reviewed_today"),
        value: reviewed_today_count,
        container_class: "rounded-2xl border border-emerald-200 bg-emerald-50 p-4 shadow-sm ring-1 ring-emerald-100",
        label_class: "text-emerald-700",
        value_class: "text-emerald-800"
      }
    ]
  end

  def admin_scope_options
    {
      "posts" => t("admin.posts.index.scopes.posts"),
      "revisions" => t("admin.posts.index.scopes.revisions")
    }
  end

  def admin_filter_options(scope)
    if scope == "posts"
      {
        "all_posts" => t("admin.posts.index.filters.all_posts"),
        "awaiting_review" => t("admin.posts.index.filters.awaiting_review"),
        "rejected" => t("admin.posts.index.filters.rejected"),
        "ai_needs_admin_review" => t("admin.posts.index.filters.ai_needs_admin_review"),
        "ai_auto_approved" => t("admin.posts.index.filters.ai_auto_approved"),
        "ai_failed" => t("admin.posts.index.filters.ai_failed"),
        "ai_pending" => t("admin.posts.index.filters.ai_pending")
      }
    elsif scope == "revisions"
      {
        "pending" => t("admin.posts.index.filters.pending"),
        "open" => t("admin.posts.index.filters.open"),
        "reviewed" => t("admin.posts.index.filters.reviewed")
      }
    else
      {}
    end
  end

  def admin_scope_chip_classes(active)
    base = "rounded-full border px-3 py-1.5 text-xs font-semibold transition"
    state = if active
      "border-[#9e0000] bg-[#9e0000] text-white shadow-sm"
    else
      "border-slate-200 bg-white text-slate-600 hover:border-red-200 hover:text-[#9e0000]"
    end
    "#{base} #{state}"
  end

  def admin_filter_chip_classes(active)
    base = "rounded-full border px-3 py-1.5 text-xs font-semibold transition"
    state = if active
      "border-[#fecaca] bg-[#fff1f2] text-[#9e0000]"
    else
      "border-slate-200 bg-white text-slate-600 hover:border-red-200 hover:text-[#9e0000]"
    end
    "#{base} #{state}"
  end
end
