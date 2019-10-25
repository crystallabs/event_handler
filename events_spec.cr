require "./spec_helper"

record ClickedEvent < ::Crysterm::Event, x : Int32, y : Int32

require "../src/event_emitter"

module Crysterm

	class TestEvents
		include ::Crysterm::EventEmitter
	end

	describe Crysterm do
		it "works" do
			Event.should be_truthy
		end

		it "works for builtin events" do
			count = 0
			c = TestEvents.new
			c.on(NewListenerEvent){|e| count += 1; true}
			count.should eq 1

			h1 = ->(e : NewListenerEvent) { count += 1; true}
			c.on NewListenerEvent, h1
			count.should eq 3

			h2 = NewListenerEvent::Handler.new { count += 1; true}
			c.on NewListenerEvent, h2
			count.should eq 6

			c.on(RemoveListenerEvent){|e| count -= 1; true}
			count.should eq 9

			c.off(NewListenerEvent, h1)
			count.should eq 8

			c.off(NewListenerEvent, h2)
			count.should eq 7

			# Already removed, so shouldn't change anything
			c.off(NewListenerEvent, h2)
			count.should eq 7
		end

		it "works for custom events" do
			count = 0
			c = TestEvents.new
			c.on(ClickedEvent){|e| count += 1; true}
			count.should eq 0

			c.emit ClickedEvent, 1,1
			count.should eq 1

			c.emit ClickedEvent, 1,1
			c.emit ClickedEvent, 1,1
			count.should eq 3
		end

	end
end
