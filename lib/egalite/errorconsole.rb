
class EgaliteErrorController < Egalite::Controller
  def self.password=(pass)
    @@password=pass
  end
  def self.database=(db)
    @@database=db
  end
  def before_filter
    return false unless @@password
    Egalite::Auth::Basic.authorize(req, 'EgaliteError') { |username,password|
      username == 'admin' and password == @@password
    }
  end
  def get
    hb = Egalite::HTMLTagBuilder
    raw("<html><body>" + 
      hb.ol([ hb.a('latest','最新エラー一覧'),
              hb.a('frequent','高頻度エラー一覧'),
              hb.a('security','セキュリティエラー一覧'),
              "<form action='detail'>エラー番号: <input type='text' name='id'><input type='submit'></form>",
      ]) + "</body></html>")
  end
  def display(recs)
    hb = Egalite::HTMLTagBuilder
    raw("<body><html>" +
      table_by_array(
        ['種別番号(詳細)', '発生回数', '内容', 'URL', '削除'],
        recs.map { |rec|
          [hb.a(url_for(:action => :group, :id => rec[:md5]),rec[:md5]),
           rec[:count],
           rec[:text][0..50],
           rec[:url][0..50],
           hb.a(url_for(:action => :delete, :id => rec[:md5]),'削除'),
          ]
        }
      ) + "</body></html>")
  end
  def latest(lim)
    lim ||= 100
    display(@@database.fetch("SELECT md5, text, url, count(*) as count FROM logs WHERE checked_at is null AND severity != 'security' GROUP BY md5, text, url ORDER BY max(created_at) DESC LIMIT ?",lim.to_i))
  end
  def frequent(lim)
    lim ||= 100
    display(@@database.fetch("SELECT md5, text, url, count(*) as count FROM logs WHERE checked_at is null AND severity != 'security' GROUP BY md5, text, url ORDER BY count(*) DESC LIMIT ?",lim.to_i))
  end
  def security(lim)
    lim ||= 100
    display(@@database.fetch("SELECT md5, text, url, count(*) as count FROM logs WHERE checked_at is null AND severity == 'security' GROUP BY md5, text, url ORDER BY count(*) DESC LIMIT ?",lim.to_i))
  end
  def group(md5)
    rec = @@database[:logs].filter(:md5 => md5).first
    raw("<html><body>"+Egalite::HTMLTagBuilder.ul([
      rec[:md5],
      rec[:url],
      rec[:text],
    ]) +"</body></html>")
  end
  def delete(md5)
    @@database[:logs].filter(:md5 => md5).update(:checked_at => Time.now)
    redirect :action => nil
  end
  def detail(id)
    rec = @@database[:logs].filter(:id => id.to_i).first
    return "no record found." unless rec
    raw("<html><body>"+Egalite::HTMLTagBuilder.ul([
      rec[:id],
      rec[:severity],
      rec[:created_at],
      rec[:md5],
      rec[:ipaddress],
      rec[:url],
      rec[:text],
    ]) +"</body></html>")
  end
end

