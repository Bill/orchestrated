require 'spec_helper'

require 'orchestrated'

describe 'performing static analysis' do
  context 'on a FirstCompletion' do
    let(:completion){Orchestrated::FirstCompletion.new}
    context 'that is empty' do
      # chose this behavior to align with Ruby Enumerable#any?
      it 'should raise an error since it can never be complete' do
        expect{Second.new.orchestrated(completion).do_second_thing(5)}.to raise_error
      end
    end
    context 'that contains only (static) Incompletes' do
      before(:each){completion<<Orchestrated::Incomplete.new}
      it 'should raise an error since it can never be complete' do
        expect{Second.new.orchestrated(completion).do_second_thing(5)}.to raise_error
      end
    end
    context 'that directly containins a (static) Complete' do
      before(:each){completion<<Orchestrated::Complete.new}
      it 'should be complete immediately' do
        expect{completion.complete?}.to be_true
      end
    end
  end
  context 'on a LastCompletion' do
    let(:completion){Orchestrated::LastCompletion.new}
    context 'that is empty' do
      # chose this behavior to align with Ruby Enumerable#all?
      it 'should be complete immediately' do
        expect{completion.complete?}.to be_true
      end
    end
    context 'that contains only (static) Completes' do
      before(:each){completion<<Orchestrated::Complete.new}
      it 'should be complete immediately' do
        expect{completion.complete?}.to be_true
      end
    end
    context 'that directly contains a (static) Incomplete' do
      before(:each){completion<<Orchestrated::Incomplete.new}
      it 'should raise an error since it can never be complete' do
        expect{Second.new.orchestrated(completion).do_second_thing(5)}.to raise_error
      end
    end
  end
end
