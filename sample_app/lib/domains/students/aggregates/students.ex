defmodule Domains.Students.Aggregates.Students do
	@behavior Commanded.Aggregates.AggregateLifespan
	defstruct students_uuid: nil

	alias __MODULE__

	alias Domains.Students.Aggregates.{Students}

	alias Domains.Students.Commands.{
		AddStudent
	}
	alias Domains.Students.Events.{
		StudentAdded
	}

	def execute(%Students{}, %AddStudent{} = add) do
			IO.inspect "[[[[ EXECUTE =) STUDENT AGGREGATE ]]]]"

			%AddStudent{
				students_uuid: add.students_uuid
			}
	end

	def apply(%Students{} = student, %AddStudent{} = add) do
		IO.inspect "[[[[[ APPLY =) STUDENT AGGREGATE ]]]]]"

		%Students{
			student
				| students_uuid: "6fa38edb-dcda-4eaf-bdcb-74d229c1692a"
		}
	end
end
