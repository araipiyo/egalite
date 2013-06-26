# -*- coding: utf-8 -*-
require 'scanf'

module Rack::Ketai::Carrier
  class Au < Abstract
    USER_AGENT_REGEXP = /^(?:KDDI|UP.Browser\/.+?)-(.+?) /
  end
end

class Rack::Ketai::Carrier::Au
  class Filter < ::Rack::Ketai::Carrier::Abstract::SjisFilter
      
    def inbound(env)
      # au SJISバイナリ -> 絵文字ID表記
      request = Rack::Request.new(env)
      
      request.params  # 最低でも1回呼んでないと query_stringが未設定
      
      converter = lambda do |value|
        value.gsub(sjis_regexp) do |match|
          format("[e:%03X]", EMOJI_TO_EMOJIID[match])
        end
      end
      deep_apply(request.env["rack.request.query_hash"], &converter)
      deep_apply(request.env["rack.request.form_hash"], &converter)
      
      # 文字コード変換
      super(request.env)
    end
    
    def outbound(status, headers, body)
      status, headers, body = super

      return [status, headers, body] unless body[0]

      body = body.collect do |str|
        str.gsub(/\[e:([0-9A-F]{3})\]/) do |match|
          emojiid = $1.scanf('%X').first
          sjis = EMOJIID_TO_EMOJI[emojiid]
          if sjis
            # 絵文字があるので差替え
            sjis
          else
            # 絵文字がないので代替文字列
            emoji_data = EMOJI_DATA[emojiid]
            NKF.nkf('-Ws', (emoji_data[:fallback] || emoji_data[:name] || '〓'))
          end
        end
      end
      
      content = (body.is_a?(Array) ? body[0] : body).to_s
      headers['Content-Length'] = (content.respond_to?(:bytesize) ? content.bytesize : content.size).to_s if headers.member?('Content-Length')
      
      [status, headers, body]
    end
    
    private
    # 絵文字コード -> 絵文字ID 対応表から、絵文字コード検出用の正規表現をつくる
    # 複数の絵文字の組み合わせのものを前におくことで
    # そっちを優先的にマッチさせる
    def sjis_regexp
      @sjis_regexp if @sjis_regexp
      matchers = if RUBY_VERSION >= '1.9.1'
                   EMOJI_TO_EMOJIID.keys.sort_by{ |codes| - codes.size }.collect{ |sjis| Regexp.new(Regexp.escape(sjis), nil)}
                 else
                   EMOJI_TO_EMOJIID.keys.sort_by{ |codes| - codes.size }.collect{ |sjis| Regexp.new(Regexp.escape(sjis, 's'), nil, 's')}
                 end
      @sjis_regexp = Regexp.union(*matchers)
    end

  end
end

# 変換テーブル読み込み
require 'rack/ketai/carrier/emoji/ausjisstrtoemojiid'

Rack::Ketai::Carrier::Au.filters = [Rack::Ketai::Carrier::Au::Filter.instance]

