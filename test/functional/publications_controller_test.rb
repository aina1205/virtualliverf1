require 'test_helper'

class PublicationsControllerTest < ActionController::TestCase
  
  fixtures :all

  include AuthenticatedTestHelper
  include RestTestCases
  
  def setup
    WebMock.allow_net_connect!
    login_as(:quentin)
  end

  def rest_api_test_object
    @object=publications(:taverna_paper_pubmed)
    @object=publications(:taverna_paper_pubmed)
  end
  
  def test_title
    get :index
    assert_select "title",:text=>/The Sysmo SEEK Publications.*/, :count=>1
  end
  
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:publications)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should not relate assays thay are not authorized for edit during create publication" do
    assay=assays(:metabolomics_assay)
    assert_difference('Publication.count') do
      post :create, :publication => {:pubmed_id => 3,:projects=>[projects(:sysmo_project)]},:assay_ids=>[assay.id.to_s]
    end

    assert_redirected_to edit_publication_path(assigns(:publication))
    p=assigns(:publication)
    assert_equal 0,p.related_assays.count
  end

  test "should create publication" do
    login_as(:model_owner) #can edit assay
    assay=assays(:metabolomics_assay)
    assert_difference('Publication.count') do
      post :create, :publication => {:pubmed_id => 3,:projects=>[projects(:sysmo_project)] },:assay_ids=>[assay.id.to_s]
    end

    assert_redirected_to edit_publication_path(assigns(:publication))
    p=assigns(:publication)
    assert_equal 1,p.related_assays.count
    assert p.related_assays.include? assay
  end
  
  test "should create doi publication" do
    assert_difference('Publication.count') do
      post :create, :publication => {:doi => "10.1371/journal.pone.0004803", :projects=>[projects(:sysmo_project)] } #10.1371/journal.pone.0004803.g001 10.1093/nar/gkl320
    end

    assert_redirected_to edit_publication_path(assigns(:publication))
  end

  test "should create doi publication with doi prefix" do
    assert_difference('Publication.count') do
      post :create, :publication => {:doi => "DOI: 10.1371/journal.pone.0004803", :projects=>[projects(:sysmo_project)] } #10.1371/journal.pone.0004803.g001 10.1093/nar/gkl320
    end

    assert_not_nil assigns(:publication)
    assert_redirected_to edit_publication_path(assigns(:publication))
    publication = assigns(:publication).destroy

    #formatted slightly different
    assert_difference('Publication.count') do
      post :create, :publication => {:doi => " doi:10.1371/journal.pone.0004803", :projects=>[projects(:sysmo_project)] } #10.1371/journal.pone.0004803.g001 10.1093/nar/gkl320
    end

    assert_not_nil assigns(:publication)
    assert_redirected_to edit_publication_path(assigns(:publication))
    publication = assigns(:publication).destroy

    #also test with spaces around
    assert_difference('Publication.count') do
      post :create, :publication => {:doi => "  10.1371/journal.pone.0004803  ", :projects=>[projects(:sysmo_project)] } #10.1371/journal.pone.0004803.g001 10.1093/nar/gkl320
    end

    assert_redirected_to edit_publication_path(assigns(:publication))
  end

  test "should show publication" do
    get :show, :id => publications(:one)
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => publications(:one)
    assert_response :success
  end

  test "associates assay" do
    login_as(:model_owner) #can edit assay
    p = publications(:taverna_paper_pubmed)
    original_assay = assays(:assay_with_a_publication)
    assert p.related_assays.include?(original_assay)
    assert original_assay.related_publications.include?(p)

    new_assay=assays(:metabolomics_assay)
    assert new_assay.related_publications.empty?
    
    put :update, :id => p,:author=>{},:assay_ids=>[new_assay.id.to_s]

    assert_redirected_to publication_path(p)
    p.reload
    original_assay.reload
    new_assay.reload

    assert_equal 1, p.related_assays.count

    assert !p.related_assays.include?(original_assay)
    assert !original_assay.related_publications.include?(p)

    assert p.related_assays.include?(new_assay)
    assert new_assay.related_publications.include?(p)

  end

  test "do not associate assays unauthorized for edit" do
    p = publications(:taverna_paper_pubmed)
    original_assay = assays(:assay_with_a_publication)
    assert p.related_assays.include?(original_assay)
    assert original_assay.related_publications.include?(p)

    new_assay=assays(:metabolomics_assay)
    assert new_assay.related_publications.empty?

    put :update, :id => p,:author=>{},:assay_ids=>[new_assay.id.to_s]

    assert_redirected_to publication_path(p)
    p.reload
    original_assay.reload
    new_assay.reload

    assert_equal 1, p.related_assays.count

    assert p.related_assays.include?(original_assay)
    assert original_assay.related_publications.include?(p)

    assert !p.related_assays.include?(new_assay)
    assert !new_assay.related_publications.include?(p)

  end

  test "should keep model and data associations after update" do
    p = publications(:pubmed_2)
    put :update, :id => p,:author=>{},:assay_ids=>[]

    assert_redirected_to publication_path(p)
    p.reload

    assert p.related_assays.empty?
    assert p.related_models.include?(models(:teusink))
    assert p.related_data_files.include?(data_files(:picture))
  end


  test "should associate authors" do
    p = publications(:pubmed_2)
    assert_equal 2, p.non_seek_authors.size
    assert_equal 0, p.creators.size
    
    seek_author1 = people(:modeller_person)
    seek_author2 = people(:quentin_person)
    
    #Associate a non-seek author to a seek person

    #Check the non_seek_authors (PublicationAuthors) decrease by 1, and the
    # seek_authors (AssetsCreators) increase by 1.
    assert_difference('PublicationAuthor.count', -2) do
      assert_difference('AssetsCreator.count', 2) do
        put :update, :id => p.id, :author => {p.non_seek_authors[1].id => seek_author2.id,p.non_seek_authors[0].id => seek_author1.id}
      end
    end
    
    assert_redirected_to publication_path(p)    
    p.reload
  end
  
  test "should disassociate authors" do
    p = publications(:one)
    p.creators << people(:quentin_person)
    p.creators << people(:aaron_person)
    
    assert_equal 0, p.non_seek_authors.size
    assert_equal 2, p.creators.size
    
    #Check the non_seek_authors (PublicationAuthors) increase by 2, and the
    # seek_authors (AssetsCreators) decrease by 2.
    assert_difference('PublicationAuthor.count', 2) do
      assert_difference('AssetsCreator.count', -2) do
        post :disassociate_authors, :id => p.id
      end 
    end

  end

  test "should update project" do
    p = publications(:one)
    assert_equal projects(:sysmo_project), p.projects.first
    put :update, :id => p.id, :author => {}, :publication => {:project_ids => [projects(:one).id]}
    assert_redirected_to publication_path(p)
    p.reload
    assert_equal [projects(:one)], p.projects
  end

  test "should destroy publication" do
    assert_difference('Publication.count', -1) do
      delete :destroy, :id => publications(:one).to_param
    end

    assert_redirected_to publications_path
  end
  
  test "shouldn't add paper with non-unique title" do
    #PubMed version of publication already exists, so it shouldn't re-add
    assert_no_difference('Publication.count') do
      post :create, :publication => {:doi => "10.1093/nar/gkl320" }
    end
  end

  test "should retrieve the right author order after a publication is created and after some authors are associate/disassociated with seek-profiles" do
    assert_difference('Publication.count') do
      post :create, :publication => {:doi => "10.1016/j.future.2011.08.004", :projects=>[projects(:sysmo_project)]}
    end
    publication = assigns(:publication)
    original_authors = ["Sean Bechhofer","Iain Buchan","David De Roure","Paolo Missier","John Ainsworth","Jiten Bhagat","Philip Couch","Don Cruickshank",
                        "Mark Delderfield","Ian Dunlop","Matthew Gamble","Danius Michaelides","Stuart Owen","David Newman","Shoaib Sufi","Carole Goble"]

    authors = publication.publication_author_orders.sort_by(&:order).collect{|o| o.author.first_name + ' ' + o.author.last_name}
    assert original_authors, authors

    seek_author1 = Factory(:person, :first_name => 'Stuart', :last_name => 'Owen')
    seek_author2 = Factory(:person, :first_name => 'Carole', :last_name => 'Goble')

    #Associate a non-seek author to a seek person
    assert_difference('PublicationAuthor.count', -2) do
      assert_difference('AssetsCreator.count', 2) do
        put :update, :id => publication.id, :author => {publication.non_seek_authors[12].id => seek_author1.id,publication.non_seek_authors[15].id => seek_author2.id}
      end
    end

    publication.reload
    authors = publication.publication_author_orders.sort_by(&:order).collect{|o| o.author.first_name + ' ' + o.author.last_name}
    assert original_authors, authors

    #Disassociate seek-authors
    assert_difference('PublicationAuthor.count', 2) do
      assert_difference('AssetsCreator.count', -2) do
        post :disassociate_authors, :id => publication.id
      end
    end

    publication.reload
    authors = publication.publication_author_orders.sort_by(&:order).collect{|o| o.author.first_name + ' ' + o.author.last_name}
    assert original_authors, authors
  end

  test "should display the right author order after some authors are associate with seek-profiles" do
    assert_difference('Publication.count') do
      post :create, :publication => {:doi => "10.1016/j.future.2011.08.004", :projects=>[projects(:sysmo_project)] } #10.1371/journal.pone.0004803.g001 10.1093/nar/gkl320
    end
    publication = assigns(:publication)
    original_authors = ["Sean Bechhofer","Iain Buchan","David De Roure","Paolo Missier","John Ainsworth","Jiten Bhagat","Philip Couch","Don Cruickshank",
                        "Mark Delderfield","Ian Dunlop","Matthew Gamble","Danius Michaelides","Stuart Owen","David Newman","Shoaib Sufi","Carole Goble"]

    seek_author1 = Factory(:person, :first_name => 'Stuart', :last_name => 'Owen')
    seek_author2 = Factory(:person, :first_name => 'Carole', :last_name => 'Goble')

    #Associate a non-seek author to a seek person
    assert_difference('PublicationAuthor.count', -2) do
      assert_difference('AssetsCreator.count', 2) do
        put :update, :id => publication.id, :author => {publication.non_seek_authors[12].id => seek_author1.id,publication.non_seek_authors[15].id => seek_author2.id}
      end
    end

    publication.reload
    joined_original_authors = original_authors.join(', ')
    get :show, :id => publication.id
    assert_select 'p', :text => /#{joined_original_authors}/
  end
end
