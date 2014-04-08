require 'erb'

Capistrano::Configuration.instance.load do
  def _cset(variable, *args, &block)
    set(variable, *args, &block) if !exists?(variable)
  end

  _cset(:thin_command) { 'bundle exec thin' }
  _cset(:thin_config_file) { "#{current_path}/thin.yml" }
  _cset(:thin_config) { "-C #{thin_config_file}" }

  _cset(:thin_port) { 3000 }
  _cset(:thin_pid) { 'tmp/pids/thin.pid' }
  _cset(:thin_log) { 'log/thin.log' }
  _cset(:thin_max_conns) { 1024 }
  _cset(:thin_max_persistent_conns) { 512 }

  _cset(:thin_servers) { 4 }

  namespace :deploy do
    task :start do
      run "cd #{current_path} && #{thin_command} #{thin_config} start"
    end

    task :stop do
      run "cd #{current_path} && #{thin_command} #{thin_config} stop"
    end

    task :restart do
      top.thin.config

      run "cd #{current_path} && #{thin_command} #{thin_config} -O restart"
    end
  end

  def skel_for(file)
    File.join(File.expand_path('../../skel', __FILE__), file)
  end

  def render_skel(file, target)
    run "mkdir -p #{File.dirname(target)}"
    top.upload StringIO.new(ERB.new(File.read(skel_for(file))).result(binding)), target
  end

  def retrieve_env
    fetch(:rails_env, fetch(:rack_env, fetch(:stage, :production)))
  end

  namespace :thin do
    task :config do
      render_skel "thin/thin.yml.erb", thin_config_file
    end

    task :shared_pids do
      run "mkdir -p #{shared_path}/pids"
    end

    task :rolling_restart do
      run "rm -Rf #{current_path}/tmp/pids && mkdir -p #{current_path}/tmp && ln -sf #{shared_path}/pids #{current_path}/tmp/pids"

      top.deploy.restart
    end
  end

  after 'deploy:setup', 'thin:shared_pids'

  before 'deploy:restart', 'thin:config'
  after 'deploy:symlink', 'thin:rolling_restart'
end

