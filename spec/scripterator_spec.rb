require 'spec_helper'

describe Scripterator do
  let(:scripterator) { Scripterator.new(&awesome_script) }

  class Gizmo
    attr_accessor :id
    @@current_id = -1
    @@gizmo_store = []

    def initialize
      @id = @@current_id += 1
    end

    def self.create!
      @@gizmo_store << Gizmo.new
      Gizmo.last
    end

    def self.find(id)
      @@gizmo_store[id]
    end

    def self.first
      @@gizmo_store.first
    end

    def self.last
      @@gizmo_store.last
    end

    def self.all
      @@gizmo_store
    end

    def self.count
      @@gizmo_store.count
    end

    def self.destroy_all
      @@gizmo_store = []
      @@current_id = -1
    end
  end

  class Widget
    def self.before_stuff; end
    def self.gizmo_code(gizmo); true; end
  end

  let(:awesome_script) do
    Proc.new do
      description { 'Convert gizmos to eggplant parmigiana' }
      options { {start_id: 0, end_id: 0, output_stream: StringIO.new} }
      find_gizmo_by { |id| Gizmo.find(id) }
      before   { Widget.before_stuff }
      per_record { |gizmo| Widget.gizmo_code(gizmo) }
    end
  end

  subject { scripterator.run }

  shared_examples_for 'raises an error' do
    specify do
      expect { subject }.to raise_error
    end
  end

  before { Gizmo.destroy_all }

  context 'when no start or end ID is passed' do
    let(:awesome_script) do
      Proc.new do
        description { 'Convert gizmos to eggplant parmigiana' }
        find_gizmo_by { |id| Gizmo.find(id) }
        before   { Widget.before_stuff }
        per_record { |gizmo| Widget.gizmo_code(gizmo) }
      end
    end

    it_behaves_like 'raises an error'
  end

  context 'when no per_record block is defined' do
    let(:awesome_script) { Proc.new { before { Widget.before_stuff } } }

    it_behaves_like 'raises an error'

    it 'does not run any other given blocks' do
      Widget.should_not_receive :before_stuff
      subject rescue nil
    end
  end

  context 'when there are no gizmos' do
    it 'does not run the per_record block' do
      Widget.should_not_receive :gizmo_code
      subject
    end
  end

  context 'when there are gizmos' do
    let(:num_gizmos) { 3 }

    let(:awesome_script) do
      Proc.new do
        description { 'Convert gizmos to eggplant parmigiana' }
        options { {start_id: Gizmo.first.id, end_id: Gizmo.last.id , output_stream: StringIO.new} }
        find_gizmo_by { |id| Gizmo.find(id) }
        before   { Widget.before_stuff }
        per_record { |gizmo| Widget.gizmo_code(gizmo) }
      end
    end

    before { num_gizmos.times { Gizmo.create! } }

    it 'runs the given script blocks' do
      Widget.should_receive :before_stuff
      Widget.should_receive(:gizmo_code).exactly(num_gizmos).times
      subject
    end

    context 'when not all gizmos are checked' do
      let(:awesome_script) do
        Proc.new do
          description { 'Convert gizmos to eggplant parmigiana' }
          options { {start_id: Gizmo.last.id, end_id: Gizmo.last.id, output_stream: StringIO.new } }
          find_gizmo_by { |id| Gizmo.find(id) }
          before   { Widget.before_stuff }
          per_record { |gizmo| Widget.gizmo_code(gizmo) }
        end
      end

      it 'marks only the checked IDs as checked' do
        subject
        Scripterator.checked_ids_for('Convert gizmos to eggplant parmigiana').should_not include Gizmo.first.id
        Scripterator.checked_ids_for('Convert gizmos to eggplant parmigiana').should include Gizmo.last.id
      end
    end

    context 'when some gizmos have already been checked' do
      let(:awesomescript) do
        Proc.new do
          description { 'Convert gizmos to eggplant parmigiana' }
          options  { {start_id: Gizmo.first.id, end_id: Gizmo.last.id, output_stream: StringIO.new} }
          find_gizmo_by { |id| Gizmo.find(id) }
          before   { Widget.before_stuff }
          per_record { |gizmo| Widget.gizmo_code(gizmo) }
        end
      end
      
      let(:checked_ids) { [Gizmo.first.id] }
      
      before do
        Scripterator.stub(:checked_ids_for).and_return( checked_ids )
        ScriptRedis.any_instance.stub(:already_run_for?).and_return(false)
        ScriptRedis.any_instance.stub(:already_run_for?).with(Gizmo.first.id).and_return(true)
      end

      it 'only runs the gizmo code for unchecked gizmos' do
        Widget.should_receive(:gizmo_code).exactly(num_gizmos - 1).times
        subject
      end
    end

    context 'when some gizmos fail' do
      before do
        Widget.stub :gizmo_code do |gizmo|
          raise 'Last gizmo expl0de' if gizmo.id == Gizmo.last.id
          true
        end
      end

      it 'marks only the failed IDs as failed' do
        subject
        Scripterator.failed_ids_for('Convert gizmos to eggplant parmigiana').should_not include Gizmo.first.id
        Scripterator.failed_ids_for('Convert gizmos to eggplant parmigiana').should include Gizmo.last.id
      end
    end
  end
end
