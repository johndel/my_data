# frozen_string_literal: true

module MyData::XmlParser
  extend self

  def xml_to_resource(xml:, resource:, root: nil)
    h = nokogiri_xml_to_hash(fix_xml(xml))
    h = h[root] if root

    resource.new hash_mapping(h, resource)
  end

  private

  def hash_mapping(hash, resource)
    flatten(hash, resource).each_with_object({}) do |(key, value), h|
      mappings = resource.mappings[key]

      h[key] = value_mapping(value, mappings)
    end
  end

  def value_mapping(value, mappings)
    return value if mappings[:resource].nil?

    if mappings[:collection]
      value = [value] unless value.is_a?(Array)
      value.map { |v| hash_mapping(v, mappings[:resource]) }
    else
      hash_mapping(value, mappings[:resource])
    end
  end

  def transform_xml_to_hash(xml)
    h = Hash
      .from_xml(xml)
      .deep_transform_keys(&:underscore)
    h["string"] || h
  end

  def fix_xml(xml)
    begin
      cleaned = xml.gsub(/<\?xml[^>]*\?>/, '')
      decoded = CGI.unescapeHTML(cleaned)

      if decoded.match(/<string[^>]*>(.*)<\/string>/m)
        content = $1.strip
        content.gsub!(/\A<\?xml[^>]*\?>/, '')
        content = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>#{content}"
      else
        content = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>#{decoded.strip}"
      end
      final_content = content.gsub("&lt;", "<").gsub("&gt;", ">")
      final_content.encode("UTF-8", "binary", invalid: :replace, undef: :replace, replace: "").strip
    rescue REXML::ParseException => e
      xml.gsub("&lt;", "<").gsub("&gt;", ">")
    end
  end

  def nokogiri_xml_to_hash(xml)
    doc = Nokogiri::XML(xml)
    root_name = doc.root.name.underscore
    { root_name => deep_transform_keys_underscore(node_to_hash(doc.root)) }
  end

  def deep_transform_keys_underscore(object)
    case object
    when Hash
      object.each_with_object({}) do |(k, v), result|
        result[k.to_s.underscore] = deep_transform_keys_underscore(v)
      end
    when Array
      object.map { |item| deep_transform_keys_underscore(item) }
    else
      object
    end
  end

  def node_to_hash(node)
    return node.text if node.element_children.empty?

    result = {}
    node.element_children.each do |child|
      child_hash = node_to_hash(child)
      if result[child.name]
        result[child.name] = [result[child.name]] unless result[child.name].is_a?(Array)
        result[child.name] << child_hash
      else
        result[child.name] = child_hash
      end
    end
    result
  end

  def flatten(hash, resource)
    return {} unless hash

    hash.each_with_object({}) do |(k, v), h|
      next if resource.attributes.none?(k) || !v

      mappings = resource.mappings[k]

      next h[k] = v unless mappings[:collection] && mappings[:collection_element_name]

      h[k] = v[mappings[:collection_element_name]]
    end
  end
end
