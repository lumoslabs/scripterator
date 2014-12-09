require 'spec_helper'

describe Scripterator::Runner do
  let(:runner)      { Scripterator::Runner.new(description, &awesome_script) }
  let(:description) { 'Convert widgets to eggplant parmigiana' }
  let(:options)     { {start_id: start_id, output_stream: StringIO.new} }
  let(:start_id)    { 1 }

  let(:awesome_script) do
    Proc.new do
      before          { Widget.before_stuff }
      for_each_widget { |widget| Widget.transform_a_widget(widget) }
    end
  end

  subject { runner.run(options) }

  shared_examples_for 'raises an error' do
    specify do
      expect { subject }.to raise_error
    end
  end

  it 'infers the model from the for_each block' do
    runner.send(:model_finder).should == Widget
  end

  context 'when a model block is defined' do
    let(:awesome_script) do
      Proc.new do
        model           { Widget.where(name: 'bla') }
        before          { Widget.before_stuff }
        for_each_widget { |widget| Widget.transform_a_widget(widget) }
      end
    end
    let!(:widget1) { Widget.create(name: 'foo') }
    let!(:widget2) { Widget.create(name: 'bla') }

    it 'uses the given model finder code' do
      Widget.should_receive(:transform_a_widget).once.with(widget2)
      Widget.should_not_receive(:transform_a_widget).with(widget1)
      subject
    end
  end

  context 'when no start or end ID is passed' do
    let(:options) { {} }

    it_behaves_like 'raises an error'
  end

  context 'when an id list is passed' do
    before { num_widgets.times { Widget.create! } }

    let(:num_widgets) { 3 }
    let(:options) { { id_list: Widget.all.map(&:id) } }

    it 'transforms each widget in the list' do
      options[:id_list].each do |id|
        runner.should_receive(:transform_one_record) do |arg1|
          arg1.id.should == id
        end
      end
      subject
    end
  end

  context 'when no per-record block is defined' do
    let(:awesome_script) do
      Proc.new do
        model  { Widget }
        before { Widget.before_stuff }
      end
    end

    it_behaves_like 'raises an error'

    it 'does not run any other given blocks' do
      Widget.should_not_receive :before_stuff
      subject rescue nil
    end
  end

  context 'when there are no records for the specified model' do
    it 'does not run the per-record block' do
      Widget.should_not_receive :transform_a_widget
      subject
    end
  end

  context 'when there are records for the specified model' do
    let(:num_widgets) { 3 }

    before { num_widgets.times { Widget.create! } }

    it 'runs the given script blocks' do
      Widget.should_receive :before_stuff
      Widget.should_receive(:transform_a_widget).exactly(num_widgets).times
      subject
    end

    context 'when not all records are checked' do
      let(:start_id) { Widget.last.id }

      it 'marks only the checked IDs as checked' do
        subject
        Scripterator.already_run_for?(description, Widget.first.id).should be_false
        Scripterator.checked_ids(description).should_not include Widget.first.id
        Scripterator.already_run_for?(description, Widget.last.id).should be_true
        Scripterator.checked_ids(description).should include Widget.last.id
      end
    end

    context 'when some records have already been checked' do
      let(:checked_ids) { [Widget.first.id] }

      before do
        Scripterator.stub(checked_ids: checked_ids)
        Scripterator::ScriptRedis.any_instance.stub(already_run_for?: false)
        Scripterator::ScriptRedis.any_instance.stub(:already_run_for?).with(Widget.first.id).and_return(true)
      end

      it 'only runs the per-record code for unchecked records' do
        Widget.should_receive(:transform_a_widget).exactly(num_widgets - 1).times
        subject
      end
    end

    context 'when the code for some records fails' do
      before do
        Widget.stub :transform_a_widget do |widget|
          raise 'Last widget expl0de' if widget.id == Widget.last.id
          true
        end
      end

      it 'marks only the failed IDs as failed' do
        subject
        Scripterator.failed_ids(description).should_not include Widget.first.id
        Scripterator.failed_ids(description).should include Widget.last.id
      end
    end

    context 'when Redis client is set to nil' do
      before { Scripterator.configure { |config| config.redis = nil } }
      after  { Scripterator.instance_variable_set(:@config, nil) }

      it 'runs without Redis' do
        expect { subject }.not_to raise_error
        Scripterator.checked_ids(description).should be_empty
      end
    end
  end
end
