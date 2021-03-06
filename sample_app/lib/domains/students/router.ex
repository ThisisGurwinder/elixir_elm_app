defmodule Domains.Students.Router do
	use Commanded.Commands.Router

	alias Domains.Students.Commands.{
		AddStudent
	}

	alias Domains.Students.Aggregates.Students
	alias Common.Support.Middleware.Validate

	dispatch(
		[AddStudent],
		to: Students,
		identity: :students_uuid
	)
end
