class Foo
  def bump(x)
    x+1
  end
end

describe 'rspec' do
  context 'mocking should_receive' do
    it 'should pass method arguments to my block' do
      x = 0
      block = nil
      Foo.any_instance.should_receive(:bump){|x_arg, &block_arg|
        x = x_arg
        block = block_arg
      }
      Foo.new.bump(1){|hello| puts hello}
      expect(x).to be(1)
      expect(block).to be_kind_of(Proc)
    end
  end
end
