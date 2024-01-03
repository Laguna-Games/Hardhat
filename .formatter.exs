[
  inputs: [
    "{mix,.formatter}.exs",
    "{lib,test}/**/*.{ex,exs}"
  ],
  locals_without_parens: [
    throw: :*,
    raise: :*
  ],
  line_length: 120
]
