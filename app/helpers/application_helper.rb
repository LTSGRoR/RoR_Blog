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

  def btn_submit(f, label = "Submit", variant: :primary, **opts)
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

  private

  def btn_classes(variant)
    base = "inline-flex items-center justify-center h-10 px-4 rounded-md text-sm font-medium border shadow-sm focus:outline-none focus:ring-2 focus:ring-offset-2 transition !cursor-pointer whitespace-nowrap"
    case variant
    when :primary
      base + " bg-indigo-600 border-indigo-600 text-white hover:bg-indigo-700 focus:ring-indigo-500"
    when :secondary
      base + " bg-white border-slate-300 text-slate-700 hover:bg-slate-50 focus:ring-slate-300"
    when :danger
      base + " bg-red-600 border-red-600 text-white hover:bg-red-700 focus:ring-red-500"
    when :success
      base + " bg-emerald-700 border-emerald-700 !text-white hover:bg-emerald-800 focus:ring-emerald-600"
    when :warning
      base + " bg-amber-500 border-amber-500 text-white hover:bg-amber-600 focus:ring-amber-400"
    when :ghost
      base + " bg-white border-slate-200 text-indigo-600 hover:bg-indigo-50 hover:border-indigo-200 focus:ring-indigo-300"
    else
      base + " border-transparent"
    end
  end
end
