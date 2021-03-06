class ExpressionScore

  ###
  #
  # ExpressionScore: gene-based class that holds key/value pairs of cell names and gene expression scores
  #
  ###

  include Mongoid::Document

  belongs_to :study
  belongs_to :study_file

  field :gene, type: String
  field :searchable_gene, type: String
  field :scores, type: Hash

  index({ gene: 1, study_id: 1, study_file_id: 1 }, { unique: true, background: true})
  index({ searchable_gene: 1, study_id: 1 }, { unique: false, background: true })
  index({ study_id: 1 }, { unique: false, background: true })
  index({ study_id: 1, study_file_id: 1} , { unique: false, background: true })

  validates_uniqueness_of :gene, scope: [:study_id, :study_file_id]
  validates_presence_of :gene

  def mean(cells)
    sum = 0.0
    cells.each do |cell|
      sum += self.scores[cell].to_f
    end
    sum / cells.size
  end
end
