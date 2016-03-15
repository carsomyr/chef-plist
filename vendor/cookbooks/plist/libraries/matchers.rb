# plist/libraries/matchers.rb

if defined?(ChefSpec)
  ChefSpec.define_matcher(:plist_file)

  def create_plist_file(resource)
    ChefSpec::Matchers::ResourceMatcher.new(:plist_file, :create, resource)
  end

  def update_plist_file(resource)
    ChefSpec::Matchers::ResourceMatcher.new(:plist_file, :update, resource)
  end

end
