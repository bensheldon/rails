# A value object spread across THREE decimal columns (width_cm, height_cm,
# depth_cm) and attached to Product with +composed_of+.
#
# Dimensions validates itself too, but Product maps its errors back onto the
# individual columns (see ComposedValidator with +errors_on: :columns+), so a
# form that binds plain fields to +width_cm+ etc. gets field-level errors for
# free. The cross-field rule below is the reason to validate the value object
# rather than each column on its own; it lands on +:base+ here and on
# +:dimensions+ on the Product.
class Dimensions
  include ValueObject

  # A common parcel-carrier limit: longest side + girth must not exceed this.
  MAX_LENGTH_PLUS_GIRTH_CM = 300

  attribute :width, :decimal
  attribute :height, :decimal
  attribute :depth, :decimal

  validates :width, :height, :depth, presence: true, numericality: { greater_than: 0, allow_nil: true }
  validate :must_fit_carrier_limits

  def sides
    [ width, height, depth ]
  end

  def volume
    sides.reduce(:*)
  end

  # Longest side plus the perimeter of the cross-section.
  def length_plus_girth
    shortest, middle, longest = sides.sort
    longest + 2 * (shortest + middle)
  end

  def to_s
    "#{sides.map { |side| format_side(side) }.join(' × ')} cm"
  end

  private
    def must_fit_carrier_limits
      return if sides.any?(&:nil?) || errors.any?
      return if length_plus_girth <= MAX_LENGTH_PLUS_GIRTH_CM

      errors.add(:base, :too_large, measured: format_side(length_plus_girth), limit: MAX_LENGTH_PLUS_GIRTH_CM)
    end

    def format_side(side)
      side.nil? ? "?" : side.to_s("F").delete_suffix(".0")
    end
end
