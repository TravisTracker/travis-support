# require 'spec_helper'
# require 'core_ext/module/async'
#
# describe Async do
#   let(:async_sleep) do
#     Class.new do
#       attr_accessor :done
#
#       def initialize
#         @done = Hash[*(1..5).map { |queue| [queue, 0] }.flatten]
#       end
#
#       def total_done
#         done.values.inject(&:+)
#       end
#
#       1.upto(5) do |queue|
#         define_method(:"sleep_in_queue_#{queue}") do |seconds|
#           sleep(seconds)
#           done[queue] ||= 0
#           done[queue] += 1
#         end
#         async :"sleep_in_queue_#{queue}", :queue => queue
#       end
#     end
#   end
#
#   let(:sleeper) { async_sleep.new }
#
#   it 'processes work in a separate thread, synchronized per queue' do
#     1.upto(5) do
#       sleeper.sleep_in_queue_1(0.02)
#     end
#
#     sleep(0.005)
#     sleeper.done[1].should == 0
#
#     1.upto(5) do |ix|
#       sleep(0.02)
#       sleeper.done[1].should == ix
#     end
#   end
#
#   it 'processes work in a separate thread, asynchronous in multiple queues' do
#     1.upto(5) { |queue| sleeper.send(:"sleep_in_queue_#{queue}", 0.05) }
#
#     sleep(0.005)
#     sleeper.total_done.should == 0
#
#     sleep(0.07)
#     sleeper.total_done.should == 5
#   end
# end
