module ApplicationHelper
  def btn_link_to(label, path, variant: :primary, **opts)
    classes = btn_classes(variant) + " " + (opts.delete(:class) || "")
    method = opts.delete(:method)
    data_opts = (opts.delete(:data) || {}).dup
    if method
      data_opts["turbo-method"] = method
      if opts[:data]&.dig(:confirm)
        data_opts["turbo-confirm"] = opts[:data][:confirm]
      end
    end
    link_to label, path, opts.merge(class: classes, data: data_opts)
  end

  def btn_button_to(label, path, variant: :primary, **opts)
    classes = btn_classes(variant) + " " + (opts.delete(:class) || "")
    method = opts.delete(:method)
    data_opts = (opts.delete(:data) || {}).dup

    # Extract form classes, default to inline-block so it behaves like an <a> tag
    form_opts = (opts.delete(:form) || {})
    form_class = "inline-block #{form_opts.delete(:class)}".strip

    # Note: form_opts and class are passed directly, NOT inside html: {}
    form_with(url: path, method: method, local: true, class: form_class, **form_opts) do
      button_tag label, type: "submit", class: classes, data: data_opts
    end
  end

  def btn_submit(f, label = nil, variant: :primary, **opts)
    classes = btn_classes(variant) + " transition !cursor-pointer " + (opts.delete(:class) || "")
    if opts[:name] && opts[:value]
      f.button label, type: "submit", **opts.merge(class: classes)
    else
      f.submit label, opts.merge(class: classes)
    end
  end

  def safe_back_path(fallback, blocked_patterns: [])
    referer = request.referer
    return fallback if referer.blank?

    uri = URI.parse(referer)
    return fallback if uri.host.present? && uri.host != request.host

    path = uri.path.presence || "/"
    return fallback if path == request.path

    blocked = [
      %r{/users/sign_in\z},
      %r{/users/sign_up\z},
      %r{/users/password(?:/new|/edit)?\z},
      %r{/users/confirmation(?:/new)?\z},
      %r{/users/sign_out\z}
    ] + blocked_patterns

    return fallback if blocked.any? { |pattern| pattern.match?(path) }

    query = uri.query.present? ? "?#{uri.query}" : ""
    fragment = uri.fragment.present? ? "##{uri.fragment}" : ""
    "#{path}#{query}#{fragment}"
  rescue URI::InvalidURIError
    fallback
  end

  def ai_review_reason_for(record)
    return nil unless record

    persisted_reason = record.respond_to?(:ai_last_error) ? record.ai_last_error.to_s.strip : nil
    return persisted_reason if persisted_reason.present?

    ai_status = record.respond_to?(:ai_review_status) ? record.ai_review_status.to_s : nil
    return nil if %w[pending in_progress].include?(ai_status)

    payload = record.respond_to?(:ai_decision_payload) ? record.ai_decision_payload : nil
    return nil unless payload.is_a?(Hash)

    payload["reason"].presence || payload[:reason].presence
  end

  def ai_review_percentage(value)
    return nil if value.nil?

    number_to_percentage(value.to_f * 100, precision: 0)
  end

  def reaction_thumb_icon(filled: false, classes: "h-5 w-5")
    if filled
      content_tag(:svg,
                  xmlns: "http://www.w3.org/2000/svg",
                  viewBox: "0 0 24 24",
                  fill: "currentColor",
                  class: classes,
                  aria: { hidden: true }) do
        safe_join([
          tag.path(d: "M10 10.25 12.89 4.89a1.8 1.8 0 0 1 1.58-.97c1 0 1.78.8 1.78 1.78v2.8H19c1.55 0 2.63 1.5 2.17 2.98l-1.47 5.12A2 2 0 0 1 17.78 18H10v-7.75Z"),
          tag.path(d: "M8.25 10.25H5.5c-.83 0-1.5.67-1.5 1.5v4.75c0 .83.67 1.5 1.5 1.5h2.75v-7.75Z")
        ])
      end
    else
      content_tag(:svg,
                  xmlns: "http://www.w3.org/2000/svg",
                  viewBox: "0 0 24 24",
                  fill: "none",
                  class: classes,
                  aria: { hidden: true }) do
        tag.path(d: "M9.5 10.5 12.7 4.6c.3-.5.8-.8 1.4-.8.8 0 1.4.6 1.4 1.4v3.3h3.2c1.3 0 2.2 1.3 1.8 2.5l-1.6 6.1c-.2.8-.9 1.4-1.8 1.4H9.5V10.5Zm-4 0h4v8h-4c-.8 0-1.5-.7-1.5-1.5V12c0-.8.7-1.5 1.5-1.5Z",
                 fill: "white",
                 stroke: "currentColor",
                 "stroke-width": "1.8",
                 "stroke-linecap": "round",
                 "stroke-linejoin": "round")
      end
    end
  end

  def reaction_icon(key, filled: false, classes: "h-5 w-5")
    return reaction_thumb_icon(filled: filled, classes: classes) if key.to_s == "thumbs_up"

    options = {
      xmlns: "http://www.w3.org/2000/svg",
      viewBox: "0 0 24 24",
      class: classes,
      aria: { hidden: true }
    }

    case key.to_s
    when "heart"
      options[:fill] = filled ? "currentColor" : "none"
      content_tag(:svg, **options) do
        tag.path(
          d: "M12 20.5 4.9 13.9a4.75 4.75 0 0 1 6.72-6.72L12 7.56l.38-.38a4.75 4.75 0 1 1 6.72 6.72L12 20.5Z",
          fill: filled ? "currentColor" : "white",
          stroke: filled ? nil : "currentColor",
          "stroke-width": filled ? nil : "1.8",
          "stroke-linecap": "round",
          "stroke-linejoin": "round"
        )
      end
    when "laugh"
      options[:fill] = "none"
      content_tag(:svg, **options) do
        safe_join([
          tag.circle(cx: "12", cy: "12", r: "8.25", fill: filled ? "currentColor" : "white", stroke: filled ? nil : "currentColor", "stroke-width": filled ? nil : "1.8"),
          tag.path(d: "M9.2 10.2h.01M14.8 10.2h.01", stroke: filled ? "white" : "currentColor", "stroke-width": "1.8", "stroke-linecap": "round"),
          tag.path(d: "M8.4 13.3c.9 1.35 2.17 2.02 3.6 2.02 1.43 0 2.7-.67 3.6-2.02", stroke: filled ? "white" : "currentColor", "stroke-width": "1.8", "stroke-linecap": "round", "stroke-linejoin": "round")
        ])
      end
    when "wow"
      options[:fill] = "none"
      content_tag(:svg, **options) do
        safe_join([
          tag.circle(cx: "12", cy: "12", r: "8.25", fill: filled ? "currentColor" : "white", stroke: filled ? nil : "currentColor", "stroke-width": filled ? nil : "1.8"),
          tag.circle(cx: "9.25", cy: "10", r: "0.9", fill: filled ? "white" : "currentColor"),
          tag.circle(cx: "14.75", cy: "10", r: "0.9", fill: filled ? "white" : "currentColor"),
          tag.ellipse(cx: "12", cy: "14.3", rx: "1.8", ry: "2.35", fill: filled ? "white" : "none", stroke: filled ? nil : "currentColor", "stroke-width": filled ? nil : "1.8")
        ])
      end
    when "sad"
      options[:fill] = "none"
      content_tag(:svg, **options) do
        safe_join([
          tag.circle(cx: "12", cy: "12", r: "8.25", fill: filled ? "currentColor" : "white", stroke: filled ? nil : "currentColor", "stroke-width": filled ? nil : "1.8"),
          tag.path(d: "M9.25 10h.01M14.75 10h.01", stroke: filled ? "white" : "currentColor", "stroke-width": "1.8", "stroke-linecap": "round"),
          tag.path(d: "M8.7 15.2c.82-.95 1.92-1.42 3.3-1.42 1.38 0 2.48.47 3.3 1.42", stroke: filled ? "white" : "currentColor", "stroke-width": "1.8", "stroke-linecap": "round", "stroke-linejoin": "round")
        ])
      end
    when "angry"
      options[:fill] = "none"
      content_tag(:svg, **options) do
        safe_join([
          tag.circle(cx: "12", cy: "12", r: "8.25", fill: filled ? "currentColor" : "white", stroke: filled ? nil : "currentColor", "stroke-width": filled ? nil : "1.8"),
          tag.path(d: "M8.5 10.2 10 9.3M15.5 10.2 14 9.3", stroke: filled ? "white" : "currentColor", "stroke-width": "1.8", "stroke-linecap": "round"),
          tag.path(d: "M8.7 15.25c.82-.78 1.92-1.17 3.3-1.17 1.38 0 2.48.39 3.3 1.17", stroke: filled ? "white" : "currentColor", "stroke-width": "1.8", "stroke-linecap": "round", "stroke-linejoin": "round")
        ])
      end
    else
      reaction_thumb_icon(filled: filled, classes: classes)
    end
  end

  def estimated_read_minutes(text, words_per_minute: 220)
    words = text.to_s.split.size
    [ (words.to_f / words_per_minute).ceil, 1 ].max
  end

  def post_read_minutes(post)
    estimated_read_minutes("#{post.title} #{post.body.to_plain_text}")
  end

  def post_excerpt(post, length: 190)
    truncate(post.body.to_plain_text.to_s.squish, length: length)
  end

  def ui_action_button_classes(tone:, full_width: false, size: :sm)
    base = "group inline-flex items-center justify-center gap-1.5 rounded-lg font-semibold shadow-sm transition hover:-translate-y-0.5 hover:shadow focus:outline-none focus:ring-2 focus:ring-offset-1"

    width_class = full_width ? "w-full" : ""

    size_class = case size
    when :xs
      "px-3 py-1.5 text-xs leading-none"
    when :sm
      "px-3 py-2 text-sm"
    when :sm_relaxed
      "px-4 py-2 text-sm"
    when :md
      "px-4 py-2.5 text-sm"
    else
      "px-3 py-2 text-sm"
    end

    tone_class = case tone
    when :primary_red
      "border border-[#fecaca] bg-[#fff1f2] text-[#9e0000] hover:border-[#fda4af] hover:bg-[#ffe4e6] hover:text-[#820000] focus:ring-[#fda4af]"
    when :approve
      "border border-emerald-200 bg-emerald-50 text-emerald-700 hover:border-emerald-300 hover:bg-emerald-100 hover:text-emerald-800 focus:ring-emerald-300"
    when :reject
      "border border-rose-200 bg-rose-50 text-rose-700 hover:border-rose-300 hover:bg-rose-100 hover:text-rose-800 focus:ring-rose-300"
    when :danger_outline
      "border border-rose-200 bg-white text-rose-600 hover:border-rose-300 hover:bg-rose-50 hover:text-rose-700 focus:ring-rose-300"
    when :unsuspend
      "border border-sky-200 bg-sky-50 text-sky-700 hover:border-sky-300 hover:bg-sky-100 hover:text-sky-800 focus:ring-sky-300"
    when :warning
      "border border-amber-200 bg-amber-50 text-amber-700 hover:border-amber-300 hover:bg-amber-100 hover:text-amber-800 focus:ring-amber-300"
    else
      "border border-slate-200 bg-white text-slate-700 hover:bg-slate-50 focus:ring-slate-300"
    end

    [ base, width_class, size_class, tone_class ].join(" ").squish
  end

  private

  def btn_classes(variant)
    base = "inline-flex items-center justify-center h-10 px-4 rounded-md text-sm font-medium border shadow-sm focus:outline-none focus:ring-2 focus:ring-offset-2 transition !cursor-pointer whitespace-nowrap"
    case variant
    when :primary
      base + " bg-[#9e0000] border-[#9e0000] text-white hover:bg-[#820000] focus:ring-[#9e0000]"
    when :secondary
      base + " bg-white border-slate-300 text-slate-700 hover:bg-slate-50 focus:ring-slate-300"
    when :danger
      base + " bg-red-600 border-red-600 text-white hover:bg-red-700 focus:ring-red-500"
    when :success
      base + " bg-emerald-700 border-emerald-700 !text-white hover:bg-emerald-800 focus:ring-emerald-600"
    when :warning
      base + " bg-amber-500 border-amber-500 text-white hover:bg-amber-600 focus:ring-amber-400"
    when :ghost
      base + " bg-white border-slate-200 text-[#9e0000] hover:bg-red-50 hover:border-red-200 focus:ring-red-300"
    else
      base + " border-transparent"
    end
  end
end
