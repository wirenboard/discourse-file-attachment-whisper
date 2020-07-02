# name: file-attachment-extraction
# about: Remove staff defined file attacments into a staff whisper
# version: 0.1
# authors: Jordan Seanor
# url: https://github.com/HMSAB/discourse-file-attachment-whisper.git

enabled_site_setting :file_attachment_whispers_file_extensions
require 'nokogiri'

after_initialize do
    DiscourseEvent.on(:post_created) do |post|
        if SiteSetting.file_attachment_whispers_file_extensions
            if SiteSetting.file_attachment_whispers_staff_bypass
                user = User.find_by(id: post.user_id)
                if user.staff?
                else
                    review_post(post)
                end
            else
                review_post(post)
            end
        end
    end

    DiscourseEvent.on(:post_edited) do |post|
        if SiteSetting.file_attachment_whispers_file_extensions
            if SiteSetting.file_attachment_whispers_staff_bypass
                user = User.find_by(id: post.user_id)
                if user.staff?
                else
                    review_post(post)
                end
            else
                review_post(post)
            end
        end
    end

    def review_post(post)
        if post.post_type != 4
            hasUpdated = false
            post_html = Nokogiri::HTML(post.cooked)
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
                    attachment.replace '<font color="red">' + node + '</font>'

                    # remove extra tags nokogiri adds in
                    index1 = post_html.to_s.index('body')
                    index2 = post_html.to_s.index('/body')
                    front_extra_characters = 5
                    back_extra_characters = 2

                    index1 = index1 + front_extra_characters
                    index2 = index2 - back_extra_characters

                    sub_string = post_html.to_s[index1..index2]

                    post.cooked = sub_string
                    post.save!
                    hasUpdated = true
                end
            end

            if hasUpdated
                post.raw = post.cooked
                post.save!

                if SiteSetting.file_attachment_whispers_notify
                    if links.length > 0
                        message = ""
                        links.each_with_index do |link, i|
                            message = message + "Link #" + (i + 1).to_s + '<br>' + link.to_s + "<br><br>"
                        end
                        new_post = PostCreator.create!(
                            Discourse.system_user,
                            topic_id: post.topic.id,
                            post_type: Post.types[:whisper],
                            raw: message,
                            whisper: true,
                            skip_validations: true
                        )
                    end
                end
            end
        end
    end

    def contains_restricted?(attachment)
        @restricted_file_types = SiteSetting.file_attachment_whispers_file_extensions.split('|')
        @restricted_file_types.any? { |extension| attachment['href'].include?(extension)}
    end
end
