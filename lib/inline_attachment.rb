module ActionMailer
  module PartContainer
    # Add an inline attachment to a multipart message.
    def inline_attachment(params, &block)
      params = { :content_type => params } if String === params
      params = { :disposition => "inline",
        :transfer_encoding => "base64" }.merge(params)
      params[:headers] ||= {}
      params[:headers]['Content-ID'] = params[:cid]
      part(params, &block)
    end
  end

  class Part
    def to_mail(defaults)
      part = TMail::Mail.new

      if @parts.empty?
        part.content_transfer_encoding = transfer_encoding || "quoted-printable"
        case (transfer_encoding || "").downcase
        when "base64" then
          part.body = TMail::Base64.folding_encode(body)
        when "quoted-printable"
          part.body = [normalize_new_lines(body)].pack("M*")
        else
          part.body = body
        end

        # Always set the content_type after setting the body and or parts

        # CHANGE: treat attachments and inline files the same
        if content_disposition == "attachment" || ((content_disposition == "inline") && filename)
          part.set_content_type(content_type || defaults.content_type, nil,
                                squish("charset" => nil, "name" => filename))
        else
          part.set_content_type(content_type || defaults.content_type, nil,
                                "charset" => (charset || defaults.charset))
        end

        part.set_content_disposition(content_disposition, squish("filename" => filename))
        headers.each {|k,v| part[k] = v }
        # END CHANGE

      else
        if String === body
          part = TMail::Mail.new
          part.body = body
          part.set_content_type content_type, nil, { "charset" => charset }
          part.set_content_disposition "inline"
          m.parts << part
        end

        @parts.each do |p|
          prt = (TMail::Mail === p ? p : p.to_mail(defaults))
          part.parts << prt
        end

        part.set_content_type(content_type, nil, { "charset" => charset }) if content_type =~ /multipart/
      end

      part
    end

    # TODO: Why cant we use Utils#normalize_new_lines?
    def normalize_new_lines(text)
      text.to_s.gsub(/\r\n?/, "\n")
    end
  end
end
