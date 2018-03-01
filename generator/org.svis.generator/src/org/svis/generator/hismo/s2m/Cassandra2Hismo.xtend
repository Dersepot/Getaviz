package org.svis.generator.hismo.s2m

import java.util.Set
import org.apache.commons.logging.LogFactory
import org.eclipse.emf.mwe.core.WorkflowContext
import org.eclipse.emf.mwe.core.issues.Issues
import org.eclipse.emf.mwe.core.monitor.ProgressMonitor
import org.svis.xtext.hismo.HISMOClassHistory
import org.svis.xtext.hismo.HISMOClassVersion
import org.svis.xtext.hismo.HISMONamespaceHistory
import org.svis.xtext.hismo.HismoDocument
import org.eclipse.emf.mwe.core.lib.WorkflowComponentWithModelSlot
import org.apache.commons.beanutils.BeanComparator
import org.svis.generator.famix.Famix2Famix
import org.eclipse.emf.ecore.resource.impl.ResourceImpl
import com.datastax.driver.core.Session
import org.svis.xtext.hismo.impl.HismoFactoryImpl
import org.svis.xtext.hismo.HISMONamespaceVersion
import org.svis.generator.hismo.HismoUtils
import java.util.Random
import org.svis.generator.rd.RDSettings

class Cassandra2Hismo extends WorkflowComponentWithModelSlot {
	val hismoFactory = new HismoFactoryImpl()
	var HismoDocument hismoDocument
	val log = LogFactory::getLog(class)
	val famix = new Famix2Famix
	extension HismoUtils hismoutil = new HismoUtils
	val nameComparator = new BeanComparator("name")
	var Session session
	
	override protected invokeInternal(WorkflowContext ctx, ProgressMonitor monitor, Issues issues) {
		log.info("Cassandra2Hismo has started")
		
		val client = new CassandraConnector();
    	client.connect("127.0.0.1", 9042, "mrt" );
    	session = client.getSession();
    	
    	var hismoRoot = hismoFactory.createHismoRoot
		hismoDocument = hismoFactory.createHismoDocument
		hismoRoot.hismoDocument = hismoDocument

		val Set<HISMONamespaceHistory> namespaceHistories = newTreeSet(nameComparator)
    	val Set<HISMONamespaceVersion> namespaceVersions = newTreeSet(nameComparator)
    	val Set<HISMOClassHistory> classHistories = newTreeSet(nameComparator)
    	val Set<HISMOClassVersion> classVersions = newTreeSet(nameComparator)
    	
    	val query = "SELECT * FROM commits"
    	    	    
        session.execute(query).forEach[result|
            val filename = result.getString("filename")
            if(filename.endsWith(".java")) {
            	val packagename = result.getString("packagename")
            	val commitdate = result.getDate("commitdate").toString
            	val project = result.getString("project")
            	val addedLines = result.getInt("addedlines")
            	val removedLines = result.getInt("removedlines")
            	//val id = result.getUUID("id").toString
            	
            	val fqn = project + "." + packagename + "." + filename
            	
            	var projectHistory = namespaceHistories.findFirst[value == project]
            	if(projectHistory === null) {
            		projectHistory = toNamespaceHistory(project)
            		namespaceHistories += projectHistory
            	}
            	
            	var namespaceHistory = namespaceHistories.findFirst[value == packagename]
            	if(namespaceHistory === null) {
            		namespaceHistory = toNamespaceHistory(packagename)
            		namespaceHistories += namespaceHistory
            	}
            	var namespaceVersion = namespaceVersions.findFirst[value == packagename && timestamp == commitdate]
            	if(namespaceVersion === null) {
            		namespaceVersion = toNamespaceVersion(namespaceHistory, commitdate)
            		namespaceVersions += namespaceVersion
            	}
            	var classHistory = classHistories.findFirst[value == fqn]
            	if(classHistory === null) {
            		classHistory = toClassHistory(namespaceHistory, fqn, packagename, commitdate)
            		classHistories += classHistory
            	}
            	var classVersion = classVersions.findFirst[value == packagename && timestamp == commitdate]
            	if(classVersion === null) {
            		classVersion = toClassVersion(classHistory, fqn, commitdate, addedLines - removedLines)
            		classVersions += classVersion
            	}
            }
        ]
        
        client.close
        hismoDocument.elements.filter(HISMONamespaceHistory).toList.forEach[createParent(it.value)]
        updateParents
		
		val resource = new ResourceImpl()
		var hismoList = newArrayList
		hismoList += hismoRoot
		resource.contents += hismoList
		ctx.set("hismo", hismoList)
		ctx.set("metadata", resource)
			
		log.info("Cassandra2RD has finished.")
	}
	
	def void createParent(String fqn) {
		val index = fqn.lastIndexOf(".")
		if(index < 0) return
		val parentFQN = fqn.substring(0, index)
		var parentHistory = hismoDocument.elements.filter(HISMONamespaceHistory).findFirst[value == parentFQN]
		if(parentHistory === null) {
			createParent(parentFQN)
			parentHistory = toNamespaceHistory(parentFQN)
			toNamespaceVersion(parentHistory, "foobar")
		}
	}
	
	def void updateParents() {
		hismoDocument.elements.filter(HISMONamespaceHistory).forEach[namespaceHistory|
			val index = namespaceHistory.value.lastIndexOf(".")
			if(index < 0) return
			val parentFQN = namespaceHistory.value.substring(0, index)
			var parentHistory = hismoDocument.elements.filter(HISMONamespaceHistory).findFirst[value == parentFQN]
			namespaceHistory.containingNamespaceHistory = parentHistory.createReference
		]
	}
	
	def HISMONamespaceHistory toNamespaceHistory(String fqn) {
		val namespaceHistory = hismoFactory.createHISMONamespaceHistory 
		namespaceHistory.value = fqn
		namespaceHistory.name = famix.createID(fqn)
		hismoDocument.elements += namespaceHistory
		return namespaceHistory
	}
	
	def HISMONamespaceVersion toNamespaceVersion(HISMONamespaceHistory history, String commit) {
		val namespaceVersion = hismoFactory.createHISMONamespaceVersion
		namespaceVersion.timestamp = commit
		namespaceVersion.commitId = commit
		namespaceVersion.name = history.value
		namespaceVersion.id = famix.createID(history.value + namespaceVersion.name)
		namespaceVersion.value =  history.value
		namespaceVersion.parentHistory = history.createReference
		
		history.namespaceVersions += namespaceVersion.createReference

		hismoDocument.elements += namespaceVersion

		return namespaceVersion
	}
	
	def private HISMOClassHistory toClassHistory(HISMONamespaceHistory history, String fqn, String packagename, String commitdate) {
		val classHistory = hismoFactory.createHISMOClassHistory
		classHistory.value = fqn
		classHistory.name = famix.createID(fqn + commitdate)

		history.classHistories += classHistory.createReference
		classHistory.containingNamespaceHistory = history.createReference
		history.classHistories += classHistory.createReference
		val rand = new Random();
		val n = rand.nextInt(100)
		switch (n) {
			case n < 30: classHistory.avgNumberOfIncidents = RDSettings::HEIGHT.intValue
			default: classHistory.avgNumberOfIncidents = (n-20)/10
		}

		hismoDocument.elements += classHistory
		return classHistory
	}
	
	def HISMOClassVersion toClassVersion(HISMOClassHistory history, String fqn, String commitdate, int numberOfStatements) {
		val classVersion =  hismoFactory.createHISMOClassVersion
		classVersion.timestamp = commitdate
		classVersion.commitId = commitdate
		classVersion.name = fqn
		classVersion.id = famix.createID(fqn + commitdate)
		classVersion.value = fqn
		classVersion.evolutionNumberOfStatements = numberOfStatements
		classVersion.parentHistory = history.createReference
		
		history.classVersions += classVersion.createReference

		hismoDocument.elements += classVersion
		return classVersion
	}	
}