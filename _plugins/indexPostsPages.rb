# Jekyll generator plugin to provide indices for a Jekyll based 
# website.

require 'xapian'

module Jekyll

  class IndexPage < Page
    def initialize(site, dir, pageList)
      @site = site
      @base = site.source
      @dir  = dir
      @name = 'index.html'

      puts "Adding IndexPage: #{dir}"

      self.process(@name)
      self.read_yaml(File.join(site.source, '_layouts'), 'emptyYaml.html')

      self.data['layout']      = 'index'
      self.data['title']       = dir

      breadCrumbs   = Array.new
      breadCrumbUrl = ''

      dir.sub(/^\//,'').split(/\//).each do | aDir |
        breadCrumbUrl << '/'+aDir
        aDir += '-' + IndexSite.monthNum2Name[aDir.to_i - 1] if 
          0 < aDir.to_i && aDir.to_i < 13
        breadCrumbs.push [ aDir, breadCrumbUrl+'/index.html' ]
      end

      self.data['breadCrumbs'] = breadCrumbs
      self.data['pageIndex']   = pageList
    end
  end

  class IndexSite < Generator
    include XapianBase

    def xapianIndexItem(page)
      title  = page.data['title']
      return if title.nil? || title.empty?

      url    = page.url
      anchor = "<a href=\"/blog#{url}\">#{title}</a>"

      doc = Xapian::Document.new()
      doc.data = anchor

      @xapianIndexer.document = doc
      @xapianIndexer.index_text_without_positions(
        removeStopWords(title), 1, 'S')
      @xapianIndexer.index_text_without_positions(
        removeStopWords(page.content), 1, 'XC') unless
        page.content.empty?

      # Add/replace the document to the database
      if @xapianDocId.has_key?(url) then
        puts "reIndexing: #{url}"
        @xapianDB.replace_document(@xapianDocId[url], doc)
      else
        puts "  Indexing: #{url}"
        @xapianDocId[url] = @xapianDB.add_document(doc)
      end
    end

    def addPageListToRootIndex(siteIndex, site)
      site.pages.each do | page |
        next unless page.name == 'index.html'
        next unless page.dir  == '/'

        pageList = Array.new
        siteIndex.keys.sort.each do | aDir |
          next if aDir == 'about.html'
          next if aDir == 'todo.html'
          next if aDir == 'index.html'
          next if aDir == 'feed.xml'
          next if aDir == 'partials'

          anIndex = siteIndex[aDir]

          thisDir = '/'+aDir
          if anIndex.is_a?(Hash) then
            pageList.push [aDir, thisDir+'/index.html' ]
          else
            pageList.push [aDir.sub(/\.[^\.]*$/,''), thisDir ]
          end
        end
        page.data['pageIndex'] = pageList
      end
    end

    def addNPostsToRootIndex(site)
      site.pages.each do | page |
        next unless page.name == 'currentPosts.html'
        next unless page.dir  == '/partials/'
        maxPosts = 5
        maxPosts = page.data['maxPosts'].to_i if page.data.has_key?('maxPosts')
        puts "collecting the most recent #{maxPosts} posts"
        nPosts = Array.new
        n = 1
        site.posts.docs.sort{ |a, b| b <=> a }.each do | post |
          nPosts.push(post)
          n += 1
          break if maxPosts < n
        end
        page.data['nPosts'] = nPosts
      end
    end

    def self.monthNum2Name 
      %w{Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec}
    end

    def addIndexPages(parentIndex, baseDir, site)
      return unless parentIndex.is_a?(Hash);

      pageList = Array.new
      parentIndex.each_pair do | aDir, anIndex |
        thisDir = baseDir+'/'+aDir
        addIndexPages(anIndex, thisDir, site)
        if anIndex.is_a?(Hash) then
          aDir += '-' + IndexSite.monthNum2Name[aDir.to_i - 1] if 
            0 < aDir.to_i && aDir.to_i < 13
          pageList.push [aDir, thisDir+'/index.html' ]
        else
          aDir = aDir.sub(/\.[^\.]*$/,'').sub(/^([0-9]+\/)+/,'').sub(/^[0-9]+\-[0-9]+\-/,'')
          pageList.push [aDir, baseDir+'/'+aDir+'.html' ]
        end
      end
      site.pages << IndexPage.new(site, baseDir, pageList) unless baseDir.empty?
    end

    def indexAnItem(item, itemDir, itemName, siteIndex)
      parentIndex   = siteIndex
      breadCrumbs   = Array.new
      breadCrumbUrl = ''
      itemPath = itemDir.sub(/^\//,'').split(/\//).each do | aDir |
        parentIndex[aDir] = Hash.new unless parentIndex.has_key?(aDir)
        parentIndex = parentIndex[aDir]
        breadCrumbUrl << '/'+aDir
        aDir += '-' + IndexSite.monthNum2Name[aDir.to_i - 1] if 
          0 < aDir.to_i && aDir.to_i < 13
        breadCrumbs.push [ aDir, breadCrumbUrl+'/index.html' ]
      end
      parentIndex[itemName] = item
      item.data['breadCrumbs'] = breadCrumbs
    end

    def generate(site)

      setupXapian(site)
      @indexWithStopWords = site.data['biblatexFieldsXapianTerms']

      siteIndex = Hash.new
      site.posts.docs.each do | post | 
        indexAnItem(post,
                    File.dirname(post.cleaned_relative_path()),
                    post.basename_without_ext(),
                    siteIndex)
        xapianIndexItem(post)
      end
      site.pages.each do | page | 
        indexAnItem(page,
                    page.dir(),
                    page.name(),
                    siteIndex)
        xapianIndexItem(page)
      end
      addIndexPages(siteIndex, '', site)
      addPageListToRootIndex(siteIndex, site)
      addNPostsToRootIndex(site)
      closeDownXapian
    end

  end # IndexSite

end # Jekyll
