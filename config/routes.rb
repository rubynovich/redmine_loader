if Rails::VERSION::MAJOR >= 3
  RedmineApp::Application.routes.draw do
    match 'redmine_loader/new', :controller => :loader, :action => :new, :via => :get
    match 'redmine_loader/create', :controller => :loader, :action => :create, :via => :post
  end
else
  ActionController::Routing::Routes.draw do |map|
    map.connect 'redmine_loader/:action', :controller => 'loader'
  end
end
