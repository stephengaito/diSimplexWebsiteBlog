# Jekyll module to normalize and collect all categories used in a site.

module Jekyll

  class CategoryNormalizer < Generator

    priority :highest

    def generate(site)

      # walk through the *posts* extracting the category information
      site.posts.docs.each do | aPost |
        #
        # We normalize all of the categories to ensure none are empty. 
        # (If no category is specified, then assign it the "general" 
        # category).
        #
        aPost.data['categories'] = Array.new if 
          ! aPost.data.has_key?('categories') ||
          aPost.data['categories'].nil?
        aPost.data['categories'].push('General') if 
          aPost.data['categories'].empty?
        aPost.populate_categories
      end

    end

  end # CategoryNormalizer

end # Jekyll
