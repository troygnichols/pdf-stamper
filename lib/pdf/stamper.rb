# = pdf/stamper.rb -- PDF template stamping.
#
#  Copyright (c) 2007-2009 Jason Yates

require 'rbconfig'
require 'fileutils'
require 'tmpdir'
require 'active_support/inflector/methods'

include FileUtils

module PDF
  class Stamper
    VERSION = "0.3.3"
    
    if RUBY_PLATFORM =~ /java/ # ifdef to check if your using JRuby
      require 'pdf/stamper/jruby'
    else
      require 'pdf/stamper/rjb'
    end
    # PDF::Stamper provides an interface into iText's PdfStamper allowing for the
    # editing of existing PDFs as templates. PDF::Stamper is not a PDF generator,
    # it allows you to edit existing PDFs and use them as templates.
    #
    # == Creation of templates
    #
    # Templates currently can be created using Adobe LiveCycle Designer
    # or Adobe Acrobat Professional. Using Acrobat Professional, you can create
    # a form and add textfields, checkboxes, radio buttons and buttons for images.
    #
    # == Example
    #
    # pdf = PDF::Stamper.new("my_template.pdf")
    # pdf.text :first_name, "Jason"
    # pdf.text :last_name, "Yates"
    # pdf.image :photo, "photo.jpg"
    # pdf.checkbox :hungry
    # pdf.save_as "my_output"
    
    # Set a textfield defined by key and text to value
    def text(key, value)
      @form.setField(key.to_s, value.to_s) # Value must be a string or itext will error.
    end

    # Set a checkbox to checked
    def checkbox(key)
      field_type = @form.getFieldType(key.to_s)
      return unless field_type == @acrofields.FIELD_TYPE_CHECKBOX

      all_states = @form.getAppearanceStates(key.to_s)
      yes_state = all_states.reject{|x| x == "Off"}
      
      
      @form.setField(key.to_s, yes_state.first) unless (yes_state.size == 0)
    end
    
    # Get checkbox values
    def get_checkbox_values(key)
      field_type = @form.getFieldType(key.to_s)
      return unless field_type == @acrofields.FIELD_TYPE_CHECKBOX

      @form.getAppearanceStates(key.to_s)
    end

    def circle(x, y, r)
      @canvas.circle(x, y, r)
    end

    def ellipse(x, y, width, height)
      @canvas.ellipse(x, y, x + width, y + height)
    end

    def rectangle(x, y,  width, height)
      @canvas.rectangle(x, y, width, height)
    end

    # Example
    # barcode("PDF417", "2d_barcode", "Barcode data...", aspect_ratio: 0.5)
    def barcode(format, key, value, opts = {})
      bar = create_barcode(format)
      bar.setText(value)
      opts.each do |name, opt|
        bar.send("set#{name.to_s.camelize}", opt)
      end

      coords = @form.getFieldPositions(key.to_s)
      rect = create_rectangle(coords)

      barcode_img = bar.getImage
      barcode_img.scalePercent(100, 100 * bar.getYHeight)
      barcode_img.setAbsolutePosition(
          coords[1] + (rect.getWidth - barcode_img.getScaledWidth) / 2,
          coords[2] + (rect.getHeight - barcode_img.getScaledHeight) / 2
      )

      cb = @stamp.getOverContent(coords[0].to_i)
      cb.addImage(barcode_img)
    end

    # this has to be called *before* setting field values
    def set_font(font_name)
      itr = @form.getFields.keySet.iterator
      while itr.hasNext
        field = itr.next
        @form.setFieldProperty(field, 'textfont', create_font(font_name), nil)
      end
    end
    
    # Saves the PDF into a file defined by path given.
    def save_as(file)
      File.open(file, "wb") { |f| f.write to_s }
    end
    
    private

    def fill
      @canvas.stroke()
      @stamp.setFormFlattening(true)
      @stamp.close
    end
  end
end
    
    
