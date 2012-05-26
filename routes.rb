ActionController::Routing::Routes.draw do |map|
  map.connect 'redmine_loader/:action.:format', :controller => 'loader'
end