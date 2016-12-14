play :test_ok do
  def run
    :ok
  end
end

play :test_ng do
  def run
    raise :ng
  end
end
