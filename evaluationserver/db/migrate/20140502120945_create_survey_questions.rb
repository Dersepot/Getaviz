class CreateSurveyQuestions < ActiveRecord::Migration[4.2]
  def change
    create_table :survey_questions do |t|
      t.references :survey, index: true
      t.references :question, index: true
      t.integer :position

      t.timestamps
    end
  end
end
