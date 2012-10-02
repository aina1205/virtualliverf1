require 'test_helper'

class ContentTypeDetectionTest < ActiveSupport::TestCase

  include Seek::ContentTypeDetection

  def test_is_xls
    blob = Factory :spreadsheet_content_blob
    assert blob.is_xls?
    assert is_xls?(blob)

    blob = Factory :xlsx_content_blob
    assert !blob.is_xls?
    assert !is_xls?(blob)
  end

  def test_is_xlsx
    blob = Factory :xlsx_content_blob
    assert blob.is_xlsx?
    assert is_xlsx?(blob)

    blob = Factory :spreadsheet_content_blob
    assert !blob.is_xlsx?
    assert !is_xlsx?(blob)
  end

  def test_is_excel
    blob = Factory :spreadsheet_content_blob
    assert blob.is_excel?
    assert is_excel?(blob)

    blob = Factory :xlsx_content_blob
    assert blob.is_excel?
    assert is_excel?(blob)

    blob = Factory :doc_content_blob
    assert !blob.is_excel?(blob)
    assert !is_excel?(blob)
  end

  def test_is_extractable_spreadsheet
    blob = Factory :xlsx_content_blob
    assert blob.is_extractable_spreadsheet?
    assert is_extractable_spreadsheet?(blob)

    blob = Factory :doc_content_blob
    assert !blob.is_extractable_spreadsheet?
    assert !is_extractable_spreadsheet?(blob)
  end

  def test_is_sbml
    blob = Factory :teusink_model_content_blob
    assert is_sbml?(blob)
    assert !is_jws_dat?(blob)
    assert blob.is_sbml?
    assert !blob.is_jws_dat?
  end

  def test_is_jws_dat
    blob = Factory :teusink_jws_model_content_blob
    assert !is_sbml?(blob)
    assert is_jws_dat?(blob)
    assert !blob.is_sbml?
    assert blob.is_jws_dat?
  end

  test "is supported no longer relies on extension" do
    blob = Factory :teusink_model_content_blob
    blob.original_filename = "teusink.txt"
    blob.dump_data_to_file
    assert blob.is_sbml?
    assert !blob.is_jws_dat?

    blob = Factory :teusink_jws_model_content_blob
    blob.original_filename = "jws.txt"
    blob.dump_data_to_file
    assert !blob.is_sbml?
    assert blob.is_jws_dat?
  end
  
end