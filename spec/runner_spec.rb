require 'spec_helper'

describe Scripterator::Runner do
  let(:runner)      { Scripterator::Runner.new(description, &awesome_script) }
  let(:description) { 'Convert widgets to eggplant parmigiana' }
  let(:options)     { {start_id: 0, end_id: 0, output_stream: StringIO.new} }

  let(:awesome_script) do
    Proc.new do
      model      { Widget }
      before     { Widget.before_stuff }
      per_record { |widget| Widget.widget_code(widget) }
    end
  end

  subject { runner.run(options) }

  shared_examples_for 'raises an error' do
    specify do
      expect { subject }.to raise_error
    end
  end

  context 'when no start or end ID is passed' do
    let(:options) { {} }

    it_behaves_like 'raises an error'
  end

  context 'when no model block is defined' do
    let(:awesome_script) do
      Proc.new do
        before     { Widget.before_stuff }
        per_record { |widget| Widget.widget_code(widget) }
      end
    end

    it_behaves_like 'raises an error'
  end

  context 'when no per_record block is defined' do
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

  context 'when there are no widgets' do
    it 'does not run the per_record block' do
      Widget.should_not_receive :widget_code
      subject
    end
  end

  context 'when there are widgets' do
    let(:num_widgets) { 3 }
    let(:options)     { {start_id: start_id, end_id: end_id, output_stream: StringIO.new} }
    let(:start_id)    { Widget.first.id }
    let(:end_id)      { Widget.last.id }

    before { num_widgets.times { Widget.create! } }

    it 'runs the given script blocks' do
      Widget.should_receive :before_stuff
      Widget.should_receive(:widget_code).exactly(num_widgets).times
      subject
    end

    context 'when not all widgets are checked' do
      let(:start_id) { Widget.last.id }

      it 'marks only the checked IDs as checked' do
        subject
        Scripterator.checked_ids_for('Convert widgets to eggplant parmigiana').should_not include Widget.first.id
        Scripterator.checked_ids_for('Convert widgets to eggplant parmigiana').should include Widget.last.id
      end
    end

    context 'when some widgets have already been checked' do
      let(:checked_ids) { [Widget.first.id] }

      before do
        Scripterator.stub(:checked_ids_for).and_return( checked_ids )
        Scripterator::ScriptRedis.any_instance.stub(:already_run_for?).and_return(false)
        Scripterator::ScriptRedis.any_instance.stub(:already_run_for?).with(Widget.first.id).and_return(true)
      end

      it 'only runs the widget code for unchecked widgets' do
        Widget.should_receive(:widget_code).exactly(num_widgets - 1).times
        subject
      end
    end

    context 'when some widgets fail' do
      before do
        Widget.stub :widget_code do |widget|
          raise 'Last widget expl0de' if widget.id == Widget.last.id
          true
        end
      end

      it 'marks only the failed IDs as failed' do
        subject
        Scripterator.failed_ids_for('Convert widgets to eggplant parmigiana').should_not include Widget.first.id
        Scripterator.failed_ids_for('Convert widgets to eggplant parmigiana').should include Widget.last.id
      end
    end
  end
end
