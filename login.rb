#!/usr/bin/env ruby
require 'rubygems'
require 'mechanize'
require 'logger'

settings = {
    "username" => 'CHANGEME',
    "password" => 'CHANGEME',
    "gateway_ip" => '10.0.20.1',
    "connectivity_ip" => '8.8.8.8',
    "disable_network_checks" => false,
    "ping_timeout" => 0.5,
}

begin
    require 'net/ping'
rescue LoadError
    puts "RUB: net/ping not installed, skipping network checks.."
    settings["disable_network_checks"] = true
end

module RUB
    class Login
        attr_reader :ip
        attr_writer :logger
        attr_accessor :settings
        attr_reader :error

        def initialize(logger = nil)
            @logger = logger
            @logger ||= Logger.new(STDOUT)
        end

        def login
            unless @settings['disable_network_checks'] then
                if check_network(@settings['connectivity_ip']) then
                    @error = "Already connected"
                    return false
                elsif not check_network(@settings['gateway_ip']) then
                    @error = "Not in RUB network"
                    return false
                end
            else
                @logger.info("Network checks disabled.")
            end

            a = Mechanize.new
            a.get('https://login.rz.ruhr-uni-bochum.de/index.html') do |page|
                login_page = page.link_with(:href => /start$/).click
                result_page = login_page.form_with(:name => 'loginbox') do |form|
                    form['loginid'] = @settings['username']
                    form['password'] = @settings['password']
                    @logger.debug("RUB: Trying to connect with user '#{@settings['username']}', ip: #{form['ipaddr']}")
                    submit = form.button_with(:value => /Login/)
                    result = form.submit(submit)
                    success = result.body.include?('Authentisierung gelungen')
                    unless success
                        @logger.warn("RUB: Login failed")
                        @error = "Login failed, wrong username/password"
                        return false
                    end
                    @ip = form['ipaddr']
                    @logger.info("RUB: Logged in succesfully")
                    return true
                end
            end
        end

        private
        def check_network(ip)
            @logger.debug("Pinging #{ip}")
            if got_root? then
                pt = Net::Ping::ICMP.new(ip)
            else
                pt = Net::Ping::External.new(ip)
            end

            pt.timeout = @settings['ping_timeout']
            res = pt.ping?
            @logger.warn("Error while pinging: #{pt.exception}") unless res

            return res
        end

        def got_root?
            return Process.uid == 0
        end
    end
end

if settings['username'] == "CHANGEME" or settings['password'] == "CHANGEME"
    puts "Set your username and/or password first!"
    exit
end

# when launching over nm-dispatcher..
iface = ARGV[0]
state = ARGV[1]

nolog = Logger.new(StringIO.new)
rub = RUB::Login.new(nolog)
rub.settings = settings

if ARGV.length < 2 or state == "up"
    if rub.login() then
        puts "RUB: Connected, local ip: #{rub.ip}"
    else
        puts "RUB: Connection failed, reason: #{rub.error}"
    end
end

