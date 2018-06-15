defmodule Domains.Students.Aggregates.Students do
	@behavior Commanded.Aggregates.AggregateLifespan
	defstruct students_uuid: nil

	alias __MODULE__

	alias Domains.Students.{Students}

	alias SampleAppWeb.Students.Commands.{
		AddStudent
	}
	alias SampleAppWeb.Students.Events.{
		StudentAdded
	}

	def execute(%Student{}, %AddStudent{} = add) do
			%AddStudent{
				students_uuid: add.students_uuid
			}
	end

	def apply(%Student{} = student, %AddStudent{} = add) do
		%Student{
			student
				| name: "added_new_student_name"
		}
	end
end
