require 'spec_helper'
require 'active_support/core_ext/hash/except'

describe Travis::Instrumentation do
  let(:klass) do
    Class.new do
      extend Travis::Instrumentation

      def self.name
        'Travis::Foo::Bar'
      end

      def tracked(*args)
        inner
      end
      instrument :tracked, :scope => :scope, :track => true

      def inner
        'result'
      end

      def scope
        'baz'
      end
    end
  end

  let(:object) { klass.new }
  let(:timer)  { stub('timer', :update => true) }
  let(:events) { [] }

  before :each do
    @subscriber = ActiveSupport::Notifications.subscribe /travis.foo.bar.baz/ do |key, args|
      events << [key, args]
    end
  end

  after :each do
    ActiveSupport::Notifications.unsubscribe(@subscriber)
  end

  before :each do
    Metriks.stubs(:timer).returns(timer)
  end

  describe 'instruments the method' do
    it 'sends received events' do
      object.tracked('foo')
      key, args = events.first
      key.should == 'travis.foo.bar.baz.tracked:received'
      args.except(:started_at, :level).should == { :target => object, :args => ['foo'] }
      args[:started_at].should be_a(Float)
    end

    it 'sends completed events' do
      object.tracked('foo')
      key, args = events.last
      key.should == 'travis.foo.bar.baz.tracked:completed'
      args.except(:started_at, :finished_at, :level).should == { :target => object, :args => ['foo'], :result => "result" }
      args[:started_at].should be_a(Float)
      args[:finished_at].should be_a(Float)
    end

    it 'sends completed events' do
      object.stubs(:inner).raises(StandardError, 'I FAIL!')
      object.tracked('foo') rescue nil
      key, args = events.last
      key.should == 'travis.foo.bar.baz.tracked:failed'
      args[:target].should == object
      args[:args].should == ['foo']
      args[:exception].should == ["StandardError", "I FAIL!"]
    end

    it 'sends out just two notifications' do
      object.tracked('foo')
      events.size.should == 2
    end
  end

  describe 'subscriptions' do
    before :each  do
      ActiveSupport::Notifications.stubs(:subscribe)
    end

    it 'subscribes to AS::Notification events on this class and namespaced classes' do
      ActiveSupport::Notifications.expects(:subscribe)
      object.tracked
    end
  end

  describe 'calling the method' do
    it 'meters execution of the method' do
      Metriks.expects(:timer).with('v1.travis.foo.bar.baz.tracked:completed').returns(timer)
      object.tracked
    end

    it 'still returns the return value of the instrumented method' do
      object.tracked.should == 'result'
    end

    it 'reraises the exception from the failed method call' do
      object.stubs(:inner).raises(StandardError)
      lambda { object.tracked }.should raise_error(StandardError)
    end
  end

  describe 'meters events' do
    let(:meter) { stub('meter', :mark => true) }
    let(:timer) { stub('timer', :update => true) }

    before(:each) do
      Metriks.stubs(:meter).returns(meter)
      Metriks.stubs(:timer).returns(timer)
    end

    it 'meters that the method call is completed' do
      Metriks.expects(:timer).with('v1.travis.foo.bar.baz.tracked:completed').returns(timer)
      object.tracked
    end

    it 'meters that the method call has failed' do
      object.stubs(:inner).raises(StandardError)
      Metriks.expects(:meter).with('v1.travis.foo.bar.baz.tracked:failed').returns(meter)
      object.tracked rescue nil
    end
  end

  describe 'levels' do
    let(:event) { events.last }
    let(:args) { event.last }
    let(:level) { args[:level] }

    it 'defaults the level to :info' do
      object.tracked('foo')
      level.should == :info
    end

    it 'may be set as option' do
      klass.send(:define_method, :other) { }
      klass.instrument :other, :level => :error, :scope => :scope, :track => true

      object.other
      level.should == :error
    end

    it 'does not record metrics for debug level' do
      Metriks.expects(:meter).never
      Metriks.expects(:timer).never

      klass.send(:define_method, :other) { }
      klass.instrument :other, :level => :debug, :scope => :scope, :track => true
      object.other
    end
  end
end
