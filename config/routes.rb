ActionController::Routing::Routes.draw do |map|
  map.connect 'redmine_loader/:action', :controller => 'loader'
end