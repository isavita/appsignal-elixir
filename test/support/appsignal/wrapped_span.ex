defmodule Appsignal.WrappedSpan do
  use Wrapper
  alias Appsignal.Span

  def add_error(span, error, stacktrace) do
    add(:add_error, {span, error, stacktrace})
    Span.add_error(span, error, stacktrace)
  end
end
