package org.svis.generator.tests.rd.dynamix

import static org.junit.Assert.*
import org.junit.Test
import org.junit.BeforeClass
import java.io.File
import java.io.FileNotFoundException
import org.eclipse.emf.mwe2.launch.runtime.Mwe2Launcher
import org.apache.commons.io.FileUtils
import org.svis.generator.SettingsConfiguration

class PrawnTest {
	
	@BeforeClass
	def static void launch() {
		SettingsConfiguration.getInstance("../org.svis.generator.tests/testdata/prawn/input/PrawnTest.properties")
		new Mwe2Launcher().run(#["../org.svis.generator.run/src/org/svis/generator/run/rd/Dynamix2RD.mwe2", "-p", "famixPath=testdata/prawn/input/famixDyn",
			"dynamixPath=testdata/prawn/input/dynamix","outputPath=output/rd/dynamix/prawn/original"])
	}
     
    @Test
    def testX3D() {
    	var File file1 = null
        var File file2 = null
        try {
            file1 = new File("./output/rd/dynamix/prawn/original/model.x3d")
			file2 = new File("./testdata/prawn/output/rd/dynamix/original/model.x3d")
        } catch (FileNotFoundException e) {
            e.printStackTrace
        }

        assertEquals(FileUtils.checksumCRC32(file1), FileUtils.checksumCRC32(file2))
    }
    
    @Test
	def testMetaData() {
        var File file1 = null
        var File file2 = null
        try {
            file1 = new File("./output/rd/dynamix/prawn/original/metaData.json")
			file2 = new File("./testdata/prawn/output/rd/dynamix/original/metaData.json")
        } catch (FileNotFoundException e) {
            e.printStackTrace
        }
        
		assertEquals(FileUtils.checksumCRC32(file1), FileUtils.checksumCRC32(file2))
	}
}