require 'rubygems'
require 'sequel'
require '../../egalite/egalite'
require 'digest/md5'

class User < Sequel::Model
  def User.digest(pw)
    Digest::MD5.hexdigest("#{pw}piyopiyo")
  end
  def password=(password)
    self.hashed_password = User.digest(password) if password and password.size > 0
  end
  def password
    ""
  end
  def User.lookup(email,password)
    User.filter(:email => email, :hashed_password => User.digest(password)).first
  end
end

class DefaultController < Egalite::Controller
  def get
    [
     link_to('list', :action => :list),
     link_to('create_tables', :action => :create_tables),
    ].flatten.join('<br/>')
  end
  def list
    [
     "Welcome #{session[:user_id] ? User[session[:user_id]].name : 'guest'}",
     session[:user_id] ? link_to('logout', :action => :logout) : '',
     
     "<form action='login' method='post'/>",
     "Email: <input type='text' name='email'/>",
     "Password: <input type='password' name='password'/>",
     "<input type='submit' value='login'/>",
     "</form>",
     link_to('new user', :action => :edit),
     "** username / email / hashed_password **",
     User.map { |user|
       link_to(user.name, :action => :edit, :id => user.id) + 
       " / #{user.email} / #{user.hashed_password} / " + 
       link_to('destroy', :action => :destroy, :id => user.id)
     }
    ].flatten.join('<br/>')
  end
  def login
    user = User.lookup(params[:email],params[:password])
    return "email and/or password is not correct." unless user
    
    session.create(:user_id => user.id)
    redirect :action => :list
  end
  def logout
    session.delete
    redirect :action => :list
  end
  def edit_get(id)
    id ? User[id] : {}
  end
  def edit_post(id)
    user = id ? User[id] : User.new
    user.update_with_params(params)
    user.save
    redirect :action => :list
  end
  def destroy(id)
    User[id].destroy
    redirect :action => :list
  end
  def create_tables
    db.create_table!(:sessions) {
      primary_key :id, :serial
      column :mac, :varchar
      column :updated_at, :timestamp
      column :user_id, :integer
    }
    db.create_table!(:users) {
      primary_key :id, :serial
      column :name, :varchar
      column :email, :varchar
      column :hashed_password, :varchar
    }
    redirect '/'
  end
end

ShowException = true
RouteDebug = false

begin
  db = Sequel.connect('postgres://test:test@localhost/egalite')
  User.set_dataset(db[:users])

  egalite = Egalite::Handler.new(
    :db => db,
    :session_handler => Egalite::SessionSequel
  )
  Rack::Handler::WEBrick.run(egalite, :Port => 4000)
ensure
  db.disconnect
end

