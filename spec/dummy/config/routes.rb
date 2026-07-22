Rails.application.routes.draw do
  mount Promotable::Engine => "/promotable"
  mount Avo::Engine, at: Avo.configuration.root_path
end
