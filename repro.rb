# frozen_string_literal: true

require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "rails", github: "rails/rails", branch: "main"
  gem "concurrent-ruby"
end

require "rails"
require "active_support"
require "active_support/dependencies"
require "active_support/dependencies/interlock"

# # Monkeypatch debug logging
# module ActiveSupport
#   module Concurrency
#     class ShareLock
#       def start_exclusive(purpose: nil, compatible: [])
#         synchronize do
#           puts "start_exclusive: entering with purpose=#{purpose}"
#           puts "  sharing=#{@sharing.inspect}"
#           puts "  exclusive_thread=#{@exclusive_thread.inspect}"
#           puts "  exclusive_waiting=#{@exclusive_waiting.inspect}"

#           raise "already exclusive" if @exclusive_thread
#           raise "already waiting for exclusive" if @exclusive_waiting

#           @exclusive_waiting = true
#           @exclusive_purpose = purpose
#           @exclusive_compatible = compatible

#           if busy_for_exclusive?(purpose)
#             puts "  busy_for_exclusive? returned true"
#             yield_shares(purpose: purpose, compatible: compatible, block_share: true) do
#               puts "  in yield_shares, about to wait_for"
#               wait_for(:start_exclusive) {
#                 busy = busy_for_exclusive?(purpose)
#                 puts "    busy_for_exclusive? returned #{busy}"
#                 busy
#               }
#             end
#           end

#           @exclusive_thread = Thread.current
#           @exclusive_depth += 1
#           true
#         end
#       end

#       def busy_for_exclusive?(purpose)
#         busy = @sharing.any? { |k, n|
#           is_busy = n > 0 && k != Thread.current
#           puts "    checking #{k.inspect}: n=#{n}, current=#{Thread.current.inspect}, busy=#{is_busy}"
#           is_busy
#         }
#         puts "  busy_for_exclusive?: sharing=#{@sharing.inspect}, result=#{busy}"
#         busy
#       end
#     end
#   end
# end

# Initialize a minimal Rails application
class MinimalApp < Rails::Application
  config.eager_load = false
  config.autoloader = :zeitwerk
end
Rails.application.initialize!

class ReloaderTest
  def test_nested_thread_unload_deadlock
    ready_for_unload = Concurrent::CountDownLatch.new(2)
    deadlock_detected = Concurrent::CountDownLatch.new

    # Simulate unloader thread (like Rails reloader)
    unloader = Thread.new do
      ready_for_unload.wait
      Rails.application.reloader.reload!
    end

    # Simulate outer thread with sharing lock
    Rails.application.executor.wrap do
      inner_thread = Thread.new do
        ready_for_unload.count_down
        sleep 0.2 # Give unloader time to attempt lock

        # Verify the unloader is waiting for the exclusive lock
        ActiveSupport::Dependencies.interlock.raw_state do |state|
          unloader_state = state[unloader]
          # raise "unloader is not waiting" unless unloader_state[:waiting] && unloader_state[:sleeper] == :start_exclusive
        end

        Rails.application.executor.wrap do
          ActiveSupport::Dependencies.interlock.loading { }  # like autoloading User
        end
      end

      # Outer thread tries to wait for inner thread while holding sharing lock
      ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
        ready_for_unload.count_down

        # Give threads time to deadlock
        sleep 0.3

        # Print lock state of all threads
        puts "\nLock state when deadlocked:"
        ActiveSupport::Dependencies.interlock.raw_state do |state|
          state.each do |thread, info|
            puts info
            backtrace = thread.backtrace
            if backtrace
              puts backtrace.map { |l| "    #{l}" }
            else
              puts "    <no backtrace available>"
            end
            puts
          end
        end

        inner_thread.join
      end
    end

    unloader.join
  end
end

ReloaderTest.new.test_nested_thread_unload_deadlock
