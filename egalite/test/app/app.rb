
class DefaultController < Egalite::Controller
  def get(name = 'egalite')
    [
     "hello #{name}.",
     "cookies = #{cookies.inspect}",
     "#{url_for(:action => :bar, :params => [:a,:b])}",
     "<a href='test'>template test</a>",
     link_to('params test',:action => :test2, :hoge => "p i y o", "foo[bar][1]" => 1, "foo[bar][2]" => :two),
     link_to('add cookie', :action => :set_cookie, :id => :piyopiyo),
     link_to('del cookie', :action => :delete_cookie),
    ].join('<br/>')
  end
  def test
    {:posts => [
      {:title => 'piyo', :content => 'hiyoko.'},
      {:title => 'foo', :content => 'bar.'},
    ]}
  end
  def test2
    params.inspect
  end
  def set_cookie(s)
    cookies['test'] = s
    redirect_to('/')
  end
  def delete_cookie
    cookies['test'] = {:expires => Time.now - 3600, :value => nil}
    redirect_to('/')
  end
end

class OneSlashController < Egalite::Controller
end
