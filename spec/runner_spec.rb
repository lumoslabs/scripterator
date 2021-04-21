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
      after_batch     { |batch| Widget.after_batch_stuff(batch) }
    end
  end

  subject { runner.run(options) }

  shared_examples_for 'raises an error' do
    specify do
      expect { subject }.to raise_error(StandardError)
    end
  end

  it 'infers the model from the for_each block' do
    expect(runner.send(:model_finder)).to eq Widget
  end

  context 'when a model block is defined' do
    let(:awesome_script) do
      Proc.new do
        model           { Widget.where(name: 'bla') }
        before          { Widget.before_stuff }
        for_each_widget { |widget| Widget.transform_a_widget(widget) }
        after_batch     { |batch| Widget.after_batch_stuff(batch) }
      end
    end
    let!(:widget1) { Widget.create(name: 'foo') }
    let!(:widget2) { Widget.create(name: 'bla') }

    it 'uses the given model finder code' do
      expect(Widget).to receive(:transform_a_widget).once.with(widget2)
      expect(Widget).not_to receive(:transform_a_widget).with(widget1)
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
        expect(runner).to receive(:transform_one_record) do |arg1|
          expect(arg1.id).to eq id
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
      expect(Widget).to_not receive(:before_stuff)
      subject rescue nil
    end
  end

  context 'when there are no records for the specified model' do
    it 'does not run the per-record block' do
      expect(Widget).to_not receive(:transform_a_widget)
      subject
    end
  end

  context 'when there are records for the specified model' do
    let(:num_widgets) { 3 }

    before { num_widgets.times { Widget.create! } }

    it 'runs the given script blocks' do
      expect(Widget).to receive(:before_stuff)
      expect(Widget).to receive(:transform_a_widget).exactly(num_widgets).times
      expect(Widget).to receive(:after_batch_stuff)
      subject
    end

    context 'when not all records are checked' do
      let(:start_id) { Widget.last.id }

      it 'marks only the checked IDs as checked' do
        subject
        expect(Scripterator.already_run_for?(description, Widget.first.id)).to be_falsey
        expect(Scripterator.checked_ids(description)).to_not include Widget.first.id
        expect(Scripterator.already_run_for?(description, Widget.last.id)).to be_truthy
        expect(Scripterator.checked_ids(description)).to include Widget.last.id
      end
    end

    context 'when some records have already been checked' do
      let(:checked_ids) { [Widget.first.id] }

      before do
        allow(Scripterator).to receive(:checked_ids).and_return(checked_ids)
        allow_any_instance_of(Scripterator::ScriptRedis).to receive(:already_run_for?).and_return(false)
        allow_any_instance_of(Scripterator::ScriptRedis).to receive(:already_run_for?).with(Widget.first.id).and_return(true)
      end

      it 'only runs the per-record code for unchecked records' do
        expect(Widget).to receive(:transform_a_widget).exactly(num_widgets - 1).times
        subject
      end
    end

    context 'when the code for some records fails' do
      before do
        allow(Widget).to receive(:transform_a_widget) do |widget|
          raise 'Last widget expl0de' if widget.id == Widget.last.id
          true
        end
      end

      it 'marks only the failed IDs as failed' do
        subject
        expect(Scripterator.failed_ids(description)).to_not include Widget.first.id
        expect(Scripterator.failed_ids(description)).to include Widget.last.id
      end
    end

    context 'when Redis client is set to nil' do
      before { Scripterator.configure { |config| config.redis = nil } }
      after  { Scripterator.instance_variable_set(:@config, nil) }

      it 'runs without Redis' do
        expect { subject }.not_to raise_error
        expect(Scripterator.checked_ids(description)).to be_empty
      end
    end
  end
end
