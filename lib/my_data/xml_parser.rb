# frozen_string_literal: true

module MyData::XmlParser
  extend self

  def xml_to_resource(xml:, resource:, root: nil)
    h = transofrm_xml_to_hash(fix_xml(xml))
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

  def fix_xml(xml)
    cleaned = xml.gsub(/<\?xml[^>]*\?>/, '')
    decoded = CGI.unescapeHTML(cleaned)

    if decoded.match(/<string[^>]*>(.*)<\/string>/m)
      content = $1.strip
      content.gsub!(/\A<\?xml[^>]*\?>/, '')
      content = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>#{content}"
    else
      content = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>#{decoded.strip}"
    end

    # Replace any remaining escaped characters and force encoding to UTF-8
    final_content = content.gsub("&lt;", "<").gsub("&gt;", ">")
    final_content.encode("UTF-8", "binary", invalid: :replace, undef: :replace, replace: "").strip
  end

  def transofrm_xml_to_hash(xml)
    hash = Hash.from_xml(xml).deep_transform_keys(&:underscore)
    hash["string"] || hash
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
