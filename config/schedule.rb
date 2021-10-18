# frozen_string_literal: true

# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Learn more: http://github.com/javan/whenever

env "DBUS_SESSION_BUS_ADDRESS", "unix:path=/run/user/1000/bus"

every 1.hour do
  # the following tasks are run in parallel (not in sequence)
  command "cd /home/doru/Projects/sandbox_rb/price_watch && bundle exec ./exe/price_watch"
end
