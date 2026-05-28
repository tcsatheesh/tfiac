terraform {
  required_version = "~> 1.9"

  # Provider-less per Constitution Principle VII. The engine performs
  # name shaping and validation only; it never touches Azure APIs.
  required_providers {}
}
