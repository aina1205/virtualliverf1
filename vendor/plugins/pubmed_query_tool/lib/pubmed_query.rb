require 'xml'
require 'open-uri'

class PubmedQuery
  attr_accessor :tool, :email
  
  FETCH_URL = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi"
  SEARCH_URL = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi"
  
  def initialize(t, e)
    self.tool = t
    self.email = e      
  end
  
  #Takes either an ID, or array of IDs and retrieves the PubMed articles for each one
  def fetch(ids, params = {})
    params[:db] = "pubmed" unless params[:db] 
    params[:retmode] = "xml"
    params[:id] = (ids.class == Array ? ids.join(",") : ids) unless params[:id]
    params[:tool] = self.tool unless params[:tool]
    params[:email] = self.email unless params[:tool]
    url = FETCH_URL + "?" + params.delete_if{|k,v| k.nil?}.to_param

    doc = query(url)  
    
    return parse_articles(doc)
  end

  #Searches pubmed and retrieves a list of pubmed IDs
  #Fields: affl, auth, ecno, jour, iss, mesh, majr, mhda, page
  #        pdat, ptyp, si, subs, subh, tiab, word, titl, lang, uid, fltr, vol 
  def search(term, params = {})
    ids = []
    params[:db] = "pubmed" unless params[:db] 
    params[:retmode] = "xml"
    params[:term] = term
    params[:tool] = self.tool unless params[:tool]
    params[:email] = self.email unless params[:tool]
    params[:retstart] = 0 unless params[:retstart]
    params[:retmax] = 5 unless params[:retmax]
    url = SEARCH_URL + "?" + params.delete_if{|k,v| k.nil?}.to_param
    
    doc = query(url)
    
    doc.find("//IdList/Id").each do |id|
      ids << id.content.to_i unless id.blank?
    end
    
    return ids
  end
  
  #THIS IS SLOWER THAN fetch(search(x))
  #Searches pubmed and retrieves a list of pubmed IDs, then queries those IDs and returns a list of
  # PubmedRecord objects. Less efficient than doing PubmedQuery#fetch(PubmedQuery#search("x"))
  #Fields: affl, auth, ecno, jour, iss, mesh, majr, mhda, page
  #        pdat, ptyp, si, subs, subh, tiab, word, titl, lang, uid, fltr, vol 
  def search_and_fetch(term, params = {})
    params[:db] = "pubmed" unless params[:db] 
    params[:retmode] = "xml"
    params[:term] = term
    params[:tool] = self.tool unless params[:tool]
    params[:email] = self.email unless params[:tool]
    params[:usehistory] = "y"
    url = SEARCH_URL + "?" + params.delete_if{|k,v| k.nil?}.to_param
    
    doc = query(url)    
    
    fetch_params = {}
    fetch_params[:WebEnv] = doc.find_first("//WebEnv").content
    fetch_params[:query_key] = doc.find_first("//QueryKey").content
    fetch_params[:db] = params[:db] 
    fetch_params[:retmode] = "xml"
    fetch_params[:tool] = params[:tool]
    fetch_params[:email] = fetch_params[:email]
    url = FETCH_URL + "?" + fetch_params.delete_if{|k,v| k.nil?}.to_param
    
    doc = query(url)
    
    return parse_articles(doc)    
  end
  
  #Takes an XML document containing a <PubmedArticleSet>, converts the contents into an array of PubmedRecord objects
  #and returns them
  def parse_articles(doc)
    records = []
    
    articles = doc.find("//PubmedArticle")    
    articles.each do |article|          
      params = {}
      
      params[:doc] = article
      
      title = article.find_first('.//ArticleTitle')
      params[:title] = title.nil? ? nil : title.content
      
      abstract = article.find_first('.//Abstract/AbstractText')
      params[:abstract] = abstract.nil? ? nil : abstract.content
      
      params[:authors] = []
      article.find('.//AuthorList/Author').each do |author|
        if author["ValidYN"] == "Y"
          last = author.find_first(".//LastName").content
          first = author.find_first(".//ForeName").content
          init = author.find_first(".//Initials").content
          params[:authors] << PubmedAuthor.new(first, last, init)
        end
      end
      
      params[:pubmed_pub_date] = parse_date(article.find_first('.//PubMedPubDate'))
      
      journal = article.find_first('.//Journal/ISOAbbreviation')
      params[:journal] = journal.nil? ? nil : journal.content
      
      params[:pmid] = article.find_first('.//PMID').content
      
      records << PubmedRecord.new(params)
    end    
    return records
  end
  
  private
  
  def query(url)
    doc = open(url)
    doc = XML::Parser.io(doc).parse
    return doc
  end
  
  def parse_date(xml_date)
    if xml_date.nil?
      return nil
    else
      return xml_date.content.split(" ")[0,3].join("/").to_date
    end
  end
end