require "open3"
require "fileutils"

Jekyll::Hooks.register :site, :post_write do |site|
  capsule = File.join(site.source, "_capsule")
  FileUtils.rm_rf(capsule)
  to_gmi = ->(url) { url.end_with?("/") ? "#{url}index.gmi" : url.sub(/\.html\z/, ".gmi") }

  posts = site.posts.docs.sort_by(&:date).reverse
  posts.each do |doc|
    md = File.read(doc.path).gsub(/\.html\)/, ".gmi)")   # interne Links auf .gmi umbiegen
    body, st = Open3.capture2("md2gemini", "-j", "-l", "paragraph", stdin_data: md)
    raise "md2gemini failed: #{doc.path}" unless st.success?

    out = File.join(capsule, to_gmi.(doc.url))
    FileUtils.mkdir_p(File.dirname(out))
    File.write(out, "# #{doc.data['title']}\n\n#{doc.date.strftime('%Y-%m-%d')}\n\n#{body}")
  end

  index = +"# #{site.config['title']}\n\n"
  posts.each { |d| index << "=> #{to_gmi.(d.url)} #{d.date.strftime('%Y-%m-%d')} #{d.data['title']}\n" }
  File.write(File.join(capsule, "index.gmi"), index)
end
