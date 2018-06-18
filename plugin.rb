# name: file-attachment-extraction
# about: Remove staff defined file attacments into a staff whisper
# version: 0.1
# authors: Jordan Seanor
# url: https://github.com/HMSAB/discourse-file-attachment-whisper.git

enabled_site_setting :random_assign_enabled
require 'nokogiri'

after_initialize do
    before do
        SiteSetting.enable_whispers = true
    end
    
    DiscourseEvent.on(:post_created) do |post|
        hasUpdated = false
        post_html = Nokogiri::HTML(post.raw)
        links = []
        @restricted_file_types = SiteSetting.file_attachment_whispers_file_extensions.split('|')
        post_html.search('a').each do |attachment|
            does_contain = @restricted_file_types.any? {
                |extension| attachment['href'].include?(extension)
            }

            if contains_restricted?(attachment)
                links.push(attachment)
                node = post_html.create_element 'p'# create paragraph element
                node.inner_html = SiteSetting.file_attachment_whispers_message
                attachment.replace '[color=red]' + node + '[/color]' # replace found link with paragraph
                post.raw = post_html
                post.save!
                hasUpdated = true
            end
        end

        if hasUpdated 
            post.raw = post.cooked
            post.save!
        end
    end

    def contains_restricted?(attachment)
        @restricted_file_types = SiteSetting.file_attachment_whispers_file_extensions.split('|')
        @restricted_file_types.any? { |extension| attachment['href'].include?(extension)}
    end
end